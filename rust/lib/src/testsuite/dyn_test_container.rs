use std::{collections::HashMap, convert::TryInto, u32};

use crate::{core_api_bindings::api_container_api::{TestMetadata, test_execution_service_client::TestExecutionServiceClient}, networks::network_context::NetworkContext};

use super::{dyn_test::DynTest, test::Test, test_context::TestContext};
use anyhow::{Context, Result};
use futures::executor::block_on;
use log::info;
use tonic::transport::Channel;

// This struct exists to shield the genericized N parameter from the HashMap
// See: https://discord.com/channels/442252698964721669/448238009733742612/809977090740977674
pub struct DynTestContainer<T: Test> {
    test: T,
}

impl<T: Test> DynTestContainer<T> {
    pub fn new(test: T) -> DynTestContainer<T> {
        return DynTestContainer{
            test,
        };
    }
}

impl<T: Test> DynTest for DynTestContainer<T> {
    fn get_test_metadata(&self) -> Result<TestMetadata> {
		let test_config = self.test.get_test_configuration();
		let mut used_artifact_urls: HashMap<String, bool> = HashMap::new();
		for (_, artifact_url) in test_config.files_artifact_urls {
			used_artifact_urls.insert(artifact_url, true);
		}
		let test_setup_timeout_seconds: u32 = self.test.get_setup_timeout().as_secs().try_into()
			.context("Could not convert execution timeout duration to u32")?;
		let test_execution_timeout_seconds: u32 = self.test.get_execution_timeout().as_secs().try_into()
			.context("Could not convert execution timeout duration to u32")?;
		let test_metadata = TestMetadata{
			is_partitioning_enabled: test_config.is_partitioning_enabled,
			used_artifact_urls: used_artifact_urls,
			test_setup_timeout_in_seconds: test_setup_timeout_seconds,
		    test_execution_timeout_in_seconds: test_execution_timeout_seconds,
		};
		return Ok(test_metadata);
    }
    
    fn setup_and_run(&mut self, channel: Channel) -> Result<()> {
        let test_config = self.test.get_test_configuration();
        let files_artifact_urls = test_config.files_artifact_urls;
        // It's weird that we're cloning the channel, but this is how you're supposed to do it according to the
        // Channel documentation since it uses a &mut self
        let client = TestExecutionServiceClient::new(channel.clone());
        let network_ctx = NetworkContext::new(client, files_artifact_urls);
        let mut registration_client = TestExecutionServiceClient::new(channel.clone());

        info!("Setting up the test network...");
		// Kick off a timer with the API in case there's an infinite loop in the user code that causes the test to hang forever
		block_on(registration_client.register_test_setup(()))
			.context("An error occurred registering the test setup with the API container")?;
        let network = self.test.setup(network_ctx)
            .context("An error occurred setting up the test network")?;
		block_on(registration_client.register_test_setup_completion(()))
			.context("An error occurred registering the test setup completion with the API container")?;
        info!("Test network set up");

        let test_ctx = TestContext{};

        info!("Executing the test...");
		block_on(registration_client.register_test_execution(()))
			.context("An error occurred registering the test execution with the API container")?;
        self.test.run(network, test_ctx)
            .context("An error occurred executing the test")?;
        info!("Test execution completed");

        return Ok(());
    }
}