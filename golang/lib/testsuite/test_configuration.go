/*
 * Copyright (c) 2020 - present Kurtosis Technologies LLC.
 * All Rights Reserved.
 */

package testsuite

import "github.com/kurtosis-tech/kurtosis-libs/golang/lib/services"

// Docs available at https://docs.kurtosistech.com/kurtosis-libs/lib-documentation
type TestConfiguration struct {
	// Docs available at https://docs.kurtosistech.com/kurtosis-libs/lib-documentation
	IsPartitioningEnabled bool

	// Docs available at https://docs.kurtosistech.com/kurtosis-libs/lib-documentation
	FilesArtifactUrls map[services.FilesArtifactID]string

}
