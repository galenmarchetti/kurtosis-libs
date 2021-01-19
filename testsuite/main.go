/*
 * Copyright (c) 2020 - present Kurtosis Technologies LLC.
 * All Rights Reserved.
 */

package main

import (
	"flag"
	"fmt"
	"github.com/kurtosis-tech/kurtosis-go/lib/client"
	"github.com/kurtosis-tech/kurtosis-go/testsuite/testsuite_impl"
	"github.com/sirupsen/logrus"
	"os"
)

func main() {
	logrus.SetFormatter(&logrus.TextFormatter{
		ForceColors:   true,
		FullTimestamp: true,
	})

	// TODO Parse both custom flags-JSON and Kurtosis flags-JSON

	// TODO Call Kurtosis.Run(customFlags, kurtosisFlags)

	// ------------------- Kurtosis-internal params -------------------------------
	// TODO with the exception of the suite log level, consolidate these into a single JSON string, so users don't need to change
	//  their main.go or Dockerfile when we push updates
	metadataFilepath := flag.String(
		"metadata-filepath",
		"",
		"The filepath of the file in which the test suite metadata should be written")
	testArg := flag.String(
		"test",
		"",
		"The name of the test to run")
	kurtosisApiIpArg := flag.String(
		"kurtosis-api-ip",
		"",
		"IP address of the Kurtosis API endpoint")
	logLevelArg := flag.String(
		"log-level",
		"",
		"String corresponding to Logrus log level that the test suite will output with",
		)
	servicesRelativeDirpathArg := flag.String(
		"services-relative-dirpath",
		"",
		"Dirpath, relative to the root of the suite execution volume, where directories for each service should be created")

	// -------------------- Testsuite-custom params ----------------------------------
	apiServiceImageArg := flag.String(
		"api-service-image",
		"",
		"Name of API example microservice Docker image that will be used to launch service containers")
	datastoreServiceImageArg := flag.String(
		"datastore-service-image",
		"",
		"Name of datastore example microservice Docker image that will be used to launch service containers")

	flag.Parse()

	level, err := logrus.ParseLevel(*logLevelArg)
	if err != nil {
		fmt.Fprintf(os.Stderr, "An error occurred parsing the log level string: %v\n", err)
		os.Exit(1)
	}
	logrus.SetLevel(level)

	kurtosisClient := client.NewKurtosisClient()
	testSuite := testsuite_impl.NewTestsuite(*apiServiceImageArg, *datastoreServiceImageArg)
	exitCode := kurtosisClient.Run(testSuite, *metadataFilepath, *servicesRelativeDirpathArg, *testArg, *kurtosisApiIpArg)
	os.Exit(exitCode)
}
