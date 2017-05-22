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

    Executes Mistral workflows, possibly different ones basing on stack action.
    A workflow could be designed to only work with some specific actions.

    The wanted behavior is described more in detail in the spec at:
    https://blueprints.launchpad.net/heat/+spec/mistral-new-resource-type-workflow-execution

    An ExternalResource looks like this:

    custom:
      type: OS::Mistral::ExternalResource
      properties:
        actions:
          CREATE:
            workflow: {get_resource: create_workflow}
            params:
              target: create_my_custom_thing
          UPDATE:
            workflow: {get_resource: update_workflow}
          DELETE:
            workflow: {get_resource: delete_workflow}
        input:
          foo1: 123
          foo2: 456
        replace_on_change_inputs:
          - foo2
        always_update: true

    NOTE: it does not remove Mistral executions after resource is deleted.
    Mistral performs cleanups of executions periodically.
    """

    support_status = support.SupportStatus(version='pike')

    default_client_name = 'mistral'

    entity = 'executions'

    _ACTION_PROPERTIES = (
        WORKFLOW, PARAMS
    ) = (
        'workflow', 'params'
    )

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

    ATTRIBUTES = (
        OUTPUT,
    ) = (
        'output',
    )

    _action_properties_schema = properties.Schema(
        properties.Schema.MAP,
        _('Dictionary which defines the workflow to run and its params.'),
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
                _('Workflow additional parameters. If workflow is reverse '
                  'typed, params requires "task_name", which defines '
                  'initial task.'),
                default={}
            ),
        }
    )

    properties_schema = {
        EX_ACTIONS: properties.Schema(
            properties.Schema.MAP,
            _('Resource action which triggers a workflow execution.'),
            schema={
                'CREATE': _action_properties_schema,
                'UPDATE': _action_properties_schema,
                'SUSPEND': _action_properties_schema,
                'RESUME': _action_properties_schema,
                'DELETE': _action_properties_schema,
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
            default='Heat managed'
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

    def _check_execution(self, action, execution_id):
        """Check execution status.

        Returns False if in IDLE, RUNNING or PAUSED
        returns True if in SUCCESS
        raises ResourceFailure if in ERROR, CANCELLED
        raises ResourceUnknownState otherwise.
        """
        execution = self.client().executions.get(execution_id)
        LOG.debug('Mistral execution %(id)s is in state '
                  '%(state)s' % {'id': execution_id,
                                 'state': execution.state})

        if execution.state in ('IDLE', 'RUNNING', 'PAUSED'):
            return False, jsonutils.loads(execution.output)

        if execution.state in ('SUCCESS',):
            return True, jsonutils.loads(execution.output)

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
            # inputs is not None if inputs changed on stack UPDATE
            if not inputs:
                inputs = self.properties[self.INPUT]
            # bring forward output from previous executions
            if action is not self.CREATE and self.resource_id:
                execution = self.client().executions.get(self.resource_id)
                erd = jsonutils.loads(execution.output)
                erd.update(action_data[self.PARAMS].get('env', {}))
                action_data[self.PARAMS]['env']['heat_extresource_data'] = erd
            execution = self.client().executions.create(
                action_data[self.WORKFLOW],
                jsonutils.dumps(inputs),
                self.properties[self.DESCRIPTION],
                **action_data[self.PARAMS])
            LOG.debug('Mistral execution %(id)s params set to '
                      '%(params)s' % {'id': execution.id,
                                      'params': action_data[self.PARAMS]})
            return execution.id

    def _check_action(self, action, execution_id):
        success = True
        # execution_id is None if no data is available for a given action
        if execution_id:
            rsrc_id = execution_id
            success, output = self._check_execution(action, execution_id)
            # set resource id using output, if found
            if success and output.get('resource_id'):
                rsrc_id = output.get('resource_id')
                LOG.debug('ExternalResource id set to %(rid)s from Mistral '
                          'execution %(eid)s output' % {'eid': execution_id,
                                                        'rid': rsrc_id})
            self.resource_id_set(rsrc_id)
        return success

    def _resolve_attribute(self, name):
        if self.resource_id:
            execution = self.client().executions.get(self.resource_id)
            return getattr(execution, name)

    def _needs_update(self, after, before, after_props, before_props,
                      prev_resource, check_init_complete=True):
        # check if we need to force replace first
        old_inputs = before_props.get(self.INPUT)
        new_inputs = after_props.get(self.INPUT)
        for i in self.properties[self.REPLACE_ON_CHANGE]:
            if old_inputs.get(i) != new_inputs.get(i):
                LOG.debug('Replacing ExternalResource %(id) instead of '
                          'updating due to change to input "%(i)s"' %
                          {"id": self.resource_id,
                           "i": i})
                raise resource.UpdateReplace(self)
        # honor always_update if found
        if self.properties[self.ALWAYS_UPDATE]:
            return True
        # call super in all other scenarios
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
        return self._check_action(self.CREATE, execution_id)

    def handle_update(self, json_snippet, tmpl_diff, prop_diff):
        new_inputs = prop_diff.get(self.INPUT)
        return self._handle_action(self.UPDATE, new_inputs)

    def check_update_complete(self, execution_id):
        return self._check_action(self.UPDATE, execution_id)

    def handle_suspend(self):
        return self._handle_action(self.SUSPEND)

    def check_suspend_complete(self, execution_id):
        return self._check_action(self.SUSPEND, execution_id)

    def handle_resume(self):
        return self._handle_action(self.RESUME)

    def check_resume_complete(self, execution_id):
        return self._check_action(self.RESUME, execution_id)

    def handle_delete(self):
        return self._handle_action(self.DELETE)

    def check_delete_complete(self, execution_id):
        return self._check_action(self.DELETE, execution_id)


def resource_mapping():
    return {
        'OS::Mistral::ExternalResource': MistralExternalResource
    }

