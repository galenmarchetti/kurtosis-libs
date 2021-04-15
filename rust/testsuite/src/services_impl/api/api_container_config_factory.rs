use std::{collections::{HashMap, HashSet}, fs::File, sync::{Arc, Mutex}};
use anyhow::{Context, Result};

use kurtosis_rust_lib::{services::{container_config_factory::ContainerConfigFactory, container_creation_config::{ContainerCreationConfig, ContainerCreationConfigBuilder, FileGeneratingFunc}, container_run_config::ContainerRunConfigBuilder, service_context::ServiceContext}};

use crate::services_impl::datastore::datastore_service::DatastoreService;

use super::api_service::ApiService;
use serde::{Deserialize, Serialize};

const PORT: u32 = 2434;
const CONFIG_FILE_KEY: &str = "config-file";
const TEST_VOLUME_MOUNTPOINT: &str = "/test-volume";

#[derive(Serialize, Deserialize, Debug)]
struct Config {
    #[serde(rename = "datastoreIp")]
    datastore_ip: String,

    #[serde(rename = "datastorePort")]
    datastore_port: u32,
}

pub struct ApiContainerConfigFactory<'obj> {
    image: String,
    datastore: &'obj DatastoreService,
}

impl<'obj> ApiContainerConfigFactory<'obj> {
    pub fn new(image: String, datastore: &'obj DatastoreService) -> ApiContainerConfigFactory {
        return ApiContainerConfigFactory{
            image,
            datastore,
        }
    }

    fn create_service(service_ctx: ServiceContext) -> ApiService {
        return ApiService::new(service_ctx, PORT);
    }
}

impl<'obj> ContainerConfigFactory<ApiService> for ApiContainerConfigFactory<'obj> {
    fn get_creation_config(&self, _container_ip_addr: &str) -> anyhow::Result<ContainerCreationConfig<ApiService>> {
        let mut ports = HashSet::new();
        ports.insert(format!("{}/tcp", PORT));

        let datastore_ip_address = self.datastore.get_ip_address().to_owned();
        let datastore_port = self.datastore.get_port().to_owned();
        let config_initialization_func = move |fp: File| -> Result<()> {
            debug!("Datastore IP: {} , port: {}", &datastore_ip_address, &datastore_port);
            let config_obj = Config{
                datastore_ip: datastore_ip_address.clone(),
                datastore_port: datastore_port.clone(),
            };
            debug!("Config obj: {:?}", config_obj);

            serde_json::to_writer(fp, &config_obj)
                .context("An error occurred serializing the config to JSON")?;

            return Ok(());
        };

        let mut file_generation_funcs: HashMap<String, Arc<Mutex<FileGeneratingFunc>>> = HashMap::new();
        file_generation_funcs.insert(
            CONFIG_FILE_KEY.to_owned(), 
            Arc::new(Mutex::new(config_initialization_func))
        );

        let result = ContainerCreationConfigBuilder::new(
                self.image.clone(), 
                TEST_VOLUME_MOUNTPOINT.to_owned(), 
                Arc::new(ApiContainerConfigFactory::create_service))
            .with_used_ports(ports)
            .with_generated_files(file_generation_funcs)
            .build();

        return Ok(result);
    }

    fn get_run_config(&self, _container_ip_addr: &str, generated_file_filepaths: std::collections::HashMap<String, std::path::PathBuf>) -> anyhow::Result<kurtosis_rust_lib::services::container_run_config::ContainerRunConfig> {
        // TODO Replace this with a productized way to start a container using only environment variables
        let config_filepath = generated_file_filepaths.get(CONFIG_FILE_KEY)
            .context(format!("No filepath found for config file key '{}'", CONFIG_FILE_KEY))?;
        let config_filepath_str = config_filepath.to_str()
            .context("An error occurred converting the config filepath to a string")?;
        debug!("Config filepath: {}", config_filepath_str);
        let start_cmd: Vec<String> = vec![
            String::from("./api.bin"),
            String::from("--config"),
            config_filepath_str.to_owned(),
        ];
        let result = ContainerRunConfigBuilder::new()
            .with_cmd_override(start_cmd)
            .build();
        return Ok(result);
    }
}