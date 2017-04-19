#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

from oslo_log import log as logging
from oslo_serialization import jsonutils

from heat.common import exception
from heat.common.i18n import _
from heat.engine import attributes
from heat.engine import constraints
from heat.engine import properties
from heat.engine import resource
from heat.engine import support

LOG = logging.getLogger(__name__)


class MistralExternalResource(resource.Resource):
    """A resource for managing Mistral workflow executions.

    Executes Mistral workflows, possibly different ones basing on input action.
    A workflow could be designed to only work with some specific actions.

    Does not remove Mistral executions after resource is deleted; Mistral
    performs cleanups of executions regularily.

    The spec at https://review.openstack.org/#/c/267770 describes the wanted
    behavior with additional details.
    """

    support_status = support.SupportStatus(version='ocata')

    default_client_name = 'mistral'

    entity = 'executions'

    PROPERTIES = (
        EX_ACTIONS,
        INPUT,
        DESCRIPTION,
        REPLACE_ON_CHANGE,
        ALWAYS_UPDATE
    ) = (
        'actions',
        'input',
        'description',
        'replace_on_change_inputs',
        'always_update'
    )

    _ACTION_PROPERTIES = (
        WORKFLOW, PARAMS
    ) = (
        'workflow', 'params'
    )

    ATTRIBUTES = (
        OUTPUT,
    ) = (
        'output',
    )

    _action_schema = properties.Schema(
        properties.Schema.MAP,
        schema={
            WORKFLOW: properties.Schema(
                properties.Schema.STRING,
                _('Workflow to execute.'),
                required=True,
                constraints=[
                    constraints.CustomConstraint('mistral.workflow')
                ],
            ),
            PARAMS: properties.Schema(
                properties.Schema.MAP,
                _("Workflow additional parameters. If Workflow is reverse "
                  "typed, params requires 'task_name', which defines "
                  "initial task."),
            ),
        }
    )

    properties_schema = {
        EX_ACTIONS: properties.Schema(
            properties.Schema.MAP,
            _('Resource action which triggers a workflow execution.'),
            schema={
                'CREATE': _action_schema,
                'UPDATE': _action_schema,
                'SUSPEND': _action_schema,
                'RESUME': _action_schema,
                'DELETE': _action_schema,
            },
            required=True
        ),
        INPUT: properties.Schema(
            properties.Schema.MAP,
            _('Dictionary which contains input for the workflows.'),
            update_allowed=True,
            default={}
        ),
        DESCRIPTION: properties.Schema(
            properties.Schema.STRING,
            _('Workflow execution description.'),
            default="Heat managed"
        ),
        REPLACE_ON_CHANGE: properties.Schema(
            properties.Schema.LIST,
            _('Which attributes cause resource replace.'),
            default=[]
        ),
        ALWAYS_UPDATE: properties.Schema(
            properties.Schema.BOOLEAN,
            _('Triggers UPDATE action execution even if input is '
              'unchanged.'),
            default=False
        ),
    }

    attributes_schema = {
        OUTPUT: attributes.Schema(
            _('Output from the execution.'),
            type=attributes.Schema.MAP
        ),
    }

    def _check_execution_success(self, action, execution_id):
        """Check execution status.

        Returns False if in IDLE, RUNNING or PAUSED
        returns True if in SUCCESS
        raises ResourceFailure if in ERROR, CANCELLED
        raises ResourceUnknownState otherwise.
        """
        execution = self.client().executions.get(execution_id)
        LOG.debug('Mistral execution %(id)s status is: '
                  '%(state)s' % {'id': execution_id,
                                 'state': execution.state})

        if execution.state in ('IDLE', 'RUNNING', 'PAUSED'):
            return False

        if execution.state in ('SUCCESS'):
            return True

        if execution.state in ('ERROR', 'CANCELLED'):
            raise exception.ResourceFailure(
                exception_or_error=execution.state,
                resource=self,
                action=action)

        raise exception.ResourceUnknownStatus(
            resource_status=execution.state,
            result=_('Mistral execution is in unknown state.'))

    def _handle_action(self, action, inputs=None):
        action_data = self.properties[self.EX_ACTIONS].get(action)
        if action_data:
            # inputs can be not None if it is updated on stack UPDATE
            if not inputs:
                inputs = self.properties[self.INPUT]
            execution = self.client().executions.create(
                action_data[self.WORKFLOW],
                jsonutils.dumps(inputs),
                self.properties[self.DESCRIPTION],
                **action_data[self.PARAMS])
            self.resource_id_set(execution.id)
            return execution.id

    def _check_complete(self, action, execution_id):
        if execution_id:
            return self._check_execution_success(action, execution_id)

    def _resolve_attribute(self, name):
        if self.resource_id:
            execution = self.client().executions.get(self.resource_id)
            if name == self.OUTPUT:
                return execution.output
            return execution.id

    def _needs_update(self, after, before, after_props, before_props,
                      prev_resource, check_init_complete=True):
        if self.properties[self.ALWAYS_UPDATE]:
            return True
        else:
            return super(MistralExternalResource,
                         self)._needs_update(after,
                                             before,
                                             after_props,
                                             before_props,
                                             prev_resource,
                                             check_init_complete)

    def handle_create(self):
        return self._handle_action(self.CREATE)

    def check_create_complete(self, execution_id):
        return self._check_complete(self.CREATE, execution_id)

    def handle_update(self, json_snippet, tmpl_diff, prop_diff):
        action = self.UPDATE
        old_inputs = self.properties[self.INPUT]
        new_inputs = prop_diff.get(self.INPUT)
        if new_inputs:
            for i in self.properties[self.REPLACE_ON_CHANGE]:
                if old_inputs.get(i) != new_inputs.get(i):
                    LOG.debug('Replacing instead of updating due to change in '
                              'input "%s"', i)
                    raise resource.UpdateReplace
        return self._handle_action(action, new_inputs)

    def check_update_complete(self, execution_id):
        return self._check_complete(self.UPDATE, execution_id)

    def handle_suspend(self):
        return self._handle_action(self.SUSPEND)

    def check_suspend_complete(self, execution_id):
        return self._check_complete(self.SUSPEND, execution_id)

    def handle_resume(self):
        return self._handle_action(self.RESUME)

    def check_resume_complete(self, execution_id):
        return self._check_complete(self.RESUME, execution_id)

    def handle_delete(self):
        return self._handle_action(self.DELETE)

    def check_delete_complete(self, execution_id):
        return self._check_complete(self.DELETE, execution_id)


def resource_mapping():
    return {
        'OS::Mistral::ExternalResource': MistralExternalResource
    }

