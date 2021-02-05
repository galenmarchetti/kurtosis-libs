use kurtosis_rust_lib::services::service;
use std::collections::{HashSet, HashMap};
use crate::services_impl::datastore::datastore_service::DatastoreService;
use std::fs::File;
use std::error::Error;

const PORT: u32 = 1323;
const PROTOCOL: &str = "tcp";
const TEST_VOLUME_MOUNTPOINT: &str = "/test-volume";

struct DatastoreContainerInitializer {
    docker_image: String,
}

impl service::DockerContainerInitializer<DatastoreService> for DatastoreContainerInitializer {
    fn get_docker_image(&self) -> &str {
        return &self.docker_image;
    }

    fn get_used_ports(&self) -> HashSet<String> {
        let mut result = HashSet::new();
        result.insert(format!("{}/{}", PORT, PROTOCOL));
        return result;
    }

    fn get_service(&self, service_id: &str, ip_addr: &str) -> DatastoreService {
        return DatastoreService::new(service_id, ip_addr, port);
    }

    fn get_files_to_mount() -> HashSet<String> {
        return HashSet::new();
    }

    fn initialize_mounted_files(mounted_files: HashMap<&str, File>) -> Result<(), dyn Error> {
        return Ok(());
    }

    fn get_files_artifact_mountpoints() -> HashMap<&str, &str> {
        return HashMap::new();
    }


    fn get_test_volume_mountpoint() -> &str {
        return TEST_VOLUME_MOUNTPOINT;
    }

    fn get_start_command(mounted_file_filepaths: HashMap<&str, &str>, ip_addr: &str) -> Result<Vec<String>, Error>;
}
