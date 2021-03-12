use std::rc::Rc;

use anyhow::{Context, Result};
use tokio::runtime::Runtime;
use tonic::transport::Channel;

use crate::core_api_bindings::api_container_api::{ExecCommandArgs, test_execution_service_client::TestExecutionServiceClient};

// This struct represents a Docker container running a service, and exposes functions for manipulating
// that container
pub struct ServiceContext {
    async_runtime: Rc<Runtime>,
    client: TestExecutionServiceClient<Channel>,
    service_id: String,
    ip_address: String,
}

impl ServiceContext {
    pub fn new(async_runtime: Rc<Runtime>, client: TestExecutionServiceClient<Channel>, service_id: String, ip_address: String) -> ServiceContext {
        return ServiceContext{
            async_runtime,
            client,
            service_id,
            ip_address,
        }
    }

    pub fn get_service_id(&self) -> &str {
        return &self.service_id;
    }

    pub fn get_ip_address(&self) -> &str {
        return &self.ip_address;
    }

    pub fn exec_command(&mut self, command: Vec<String>) -> Result<(i32, Vec<u8>)> {
        let args = ExecCommandArgs{
            service_id: self.service_id.clone(),
            command_args: command.clone(),
        };
        let req = tonic::Request::new(args);
        let resp = self.async_runtime.block_on(self.client.exec_command(req))
            .context(format!("An error occurred executing command '{:?}' on service '{}'", &command, self.service_id))?
            .into_inner();
        return Ok((resp.exit_code, resp.log_output));
    }
}