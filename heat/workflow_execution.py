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
from heat.common.i18n import _LI
from heat.engine import attributes
from heat.engine import constraints
from heat.engine import properties
from heat.engine import resource
from heat.engine import support

LOG = logging.getLogger(__name__)


class MistralWorkflowExecution(resource.Resource):
    """A resource for managing Mistral workflow executions.

    Represents Mistral workflow executions. A workflow can be
    executed multiple times providing different output basing
    on the input parameters it gets.

    Specifying actions other than the default CREATE and UPDATE will result
    in the execution being triggered in those actions. For example this would
    allow cleanup configuration to be performed during actions SUSPEND and
    DELETE. A workflow could be designed to only work with some specific
    actions.
    """

    support_status = support.SupportStatus(version='2017.1')

    default_client_name = 'mistral'

    entity = 'executions'

    PROPERTIES = (
        WORKFLOW, INPUT, DESCRIPTION, PARAMS, DEPLOY_ACTIONS
    ) = (
        'workflow', 'input', 'description', 'params', 'actions'
    )

    ALLOWED_DEPLOY_ACTIONS = (
        resource.Resource.CREATE,
        resource.Resource.UPDATE,
        resource.Resource.DELETE,
        resource.Resource.SUSPEND,
        resource.Resource.RESUME,
    )

    ATTRIBUTES = (
        OUTPUT_ATTR,
    ) = (
        'output',
    )

    properties_schema = {
        WORKFLOW: properties.Schema(
            properties.Schema.STRING,
            _('Workflow to execute.'),
            required=True,
            constraints=[
                constraints.CustomConstraint('mistral.workflow')
            ]
        ),
        INPUT: properties.Schema(
            properties.Schema.MAP,
            _('Dictionary which contains input for workflow.')
        ),
        DESCRIPTION: properties.Schema(
            properties.Schema.STRING,
            _('Workflow execution description.')
        ),
        PARAMS: properties.Schema(
            properties.Schema.MAP,
            _("Workflow additional parameters. If Workflow is reverse typed, "
              "params requires 'task_name', which defines initial task.")
        ),
        DEPLOY_ACTIONS: properties.Schema(
            properties.Schema.LIST,
            _('Which lifecycle actions of the execution resource will result '
              'in this execution being triggered.'),
            update_allowed=True,
            default=[resource.Resource.CREATE, resource.Resource.UPDATE],
            constraints=[constraints.AllowedValues(ALLOWED_DEPLOY_ACTIONS)]
        ),
    }

    attributes_schema = {
        OUTPUT_ATTR: attributes.Schema(
            _('Output from the execution.'),
            type=attributes.Schema.MAP
        ),
    }

    def _check_execution_success(self, action, execution_id):
        """Check execution status.

        Returns False if in IDLE, RUNNING or PAUSED
        returns True if in SUCCESS
        raises ResourceFailure if in ERROR, CANCELLED
        raises ResourceUnknownState otherwise
        """
        execution = self.client().executions.get(execution_id)
        LOG.debug(_LI('Execution %(id)s status is: %(status)s'),
                  {'id': execution_id, 'status': execution.state})

        if execution.state in ('IDLE', 'RUNNING', 'PAUSED'):
            return False

        if execution.state in ('SUCCESS'):
            LOG.info(_LI('Execution %(id)s completed successfully'),
                     {'id': execution_id})
            return True

        if execution.state in ('ERROR', 'CANCELLED'):
            raise exception.ResourceFailure(
                exception_or_error=execution.state,
                resource=self,
                action=action)

        raise exception.ResourceUnknownStatus(
            resource_status=execution.state,
            result=_('Execution failed'))

    def _handle_action(self, action):
        if action not in self.properties[self.DEPLOY_ACTIONS]:
            return
        execution = self.client().executions.create(
            self.properties[self.WORKFLOW],
            jsonutils.dumps(self.properties[self.INPUT]),
            self.properties[self.DESCRIPTION],
            **(self.properties[self.PARAMS]) or {})
        self.resource_id_set(execution.id)
        return execution.id

    def _check_complete(self, action, execution_id):
        if not execution_id:
            return True
        if action not in self.properties[self.DEPLOY_ACTIONS]:
            return True
        return self._check_execution_success(action, execution_id)

    def _resolve_attribute(self, name):
        if not self.resource_id:
            return jsonutils.loads('{}')
        execution = self.client().executions.get(self.resource_id)
        if name == self.OUTPUT_ATTR:
            return jsonutils.dumps(execution.output)
        return execution.id

    def handle_create(self):
        return self._handle_action(self.CREATE)

    def check_create_complete(self, execution_id):
        return self._check_complete(self.CREATE, execution_id)

    def handle_update(self):
        return self._handle_action(self.UPDATE)

    def check_update_complete(self, execution_id):
        return self._check_complete(self.UDATE, execution_id)

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
        'OS::Mistral::WorkflowExecution': MistralWorkflowExecution
    }

