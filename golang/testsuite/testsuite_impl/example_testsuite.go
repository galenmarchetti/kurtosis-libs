/*
 * Copyright (c) 2020 - present Kurtosis Technologies LLC.
 * All Rights Reserved.
 */

package testsuite_impl

import (
	"github.com/kurtosis-tech/kurtosis-libs/golang/lib/testsuite"
	"github.com/kurtosis-tech/kurtosis-libs/golang/testsuite/testsuite_impl/advanced_network_test"
	"github.com/kurtosis-tech/kurtosis-libs/golang/testsuite/testsuite_impl/basic_datastore_and_api_test"
	"github.com/kurtosis-tech/kurtosis-libs/golang/testsuite/testsuite_impl/basic_datastore_test"
	"github.com/kurtosis-tech/kurtosis-libs/golang/testsuite/testsuite_impl/exec_command_test"
	"github.com/kurtosis-tech/kurtosis-libs/golang/testsuite/testsuite_impl/files_artifact_mounting_test"
	"github.com/kurtosis-tech/kurtosis-libs/golang/testsuite/testsuite_impl/network_partition_test"
)

/*
	NEW USER ONBOARDING:
	- Refactor the name of the myCustomServiceImage property to reflect the name of your service.
*/
type ExampleTestsuite struct {
	myCustomServiceImage string
	apiServiceImage string
	datastoreServiceImage string
	isKurtosisCoreDevMode bool
}

/*
	NEW USER ONBOARDING:
	- Refactor the name of the myCustomServiceImage argument to reflect the name of your service.
*/
func NewExampleTestsuite(myCustomServiceImage string, apiServiceImage string, datastoreServiceImage string, isKurtosisCoreDevMode bool) *ExampleTestsuite {
	return &ExampleTestsuite{myCustomServiceImage: myCustomServiceImage, apiServiceImage: apiServiceImage, datastoreServiceImage: datastoreServiceImage, isKurtosisCoreDevMode: isKurtosisCoreDevMode}
}

func (suite ExampleTestsuite) GetTests() map[string]testsuite.Test {
	tests := map[string]testsuite.Test{
		"basicDatastoreTest": basic_datastore_test.NewBasicDatastoreTest(suite.datastoreServiceImage),
		"basicDatastoreAndApiTest": basic_datastore_and_api_test.NewBasicDatastoreAndApiTest(
			suite.datastoreServiceImage,
			suite.apiServiceImage,
		),
		"advancedNetworkTest": advanced_network_test.NewAdvancedNetworkTest(
			suite.datastoreServiceImage,
			suite.apiServiceImage,
		),
	}

	// This example Go testsuite is used internally, when developing on Kurtosis Core, to verify functionality
	// When this testsuite is being used in this way, some special tests (which likely won't be interesting
	//  to you) are run
	// Feel free to delete these tests as you see fit
	if suite.isKurtosisCoreDevMode {
		tests["networkPartitionTest"] = network_partition_test.NewNetworkPartitionTest(
			suite.datastoreServiceImage,
			suite.apiServiceImage,
		)
		tests["filesArtifactMountingTest"] = files_artifact_mounting_test.FilesArtifactMountingTest{}
		tests["execCommandTest"] = exec_command_test.ExecCommandTest{}
	}

	return tests
}

func (suite ExampleTestsuite) GetNetworkWidthBits() uint32 {
	return 8
}


