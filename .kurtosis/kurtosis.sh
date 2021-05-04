# Copyright (c) 2020 - present Kurtosis Technologies LLC.
# All Rights Reserved.

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! WARNING !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#
#      Do not modify this file! It will get overwritten when you upgrade Kurtosis!
#
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! WARNING !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

set -euo pipefail



# ============================================================================================
#                                      Constants
# ============================================================================================
# The directory where Kurtosis will store files it uses in between executions, e.g. access tokens
# Can make this configurable if needed
KURTOSIS_DIRPATH="${HOME}/.kurtosis"

KURTOSIS_CORE_TAG="mieubrisse_test-suite-as-server"
KURTOSIS_DOCKERHUB_ORG="kurtosistech"
INITIALIZER_IMAGE="${KURTOSIS_DOCKERHUB_ORG}/kurtosis-core_initializer:${KURTOSIS_CORE_TAG}"
API_IMAGE="${KURTOSIS_DOCKERHUB_ORG}/kurtosis-core_api:${KURTOSIS_CORE_TAG}"

POSITIONAL_ARG_DEFINITION_FRAGMENTS=2



# ============================================================================================
#                                      Arg Parsing
# ============================================================================================
function print_help_and_exit() {
    echo ""
    echo "$(basename "${0}") [--custom-params custom_params_json] [--client-id client_id] [--client-secret client_secret] [--debug] [--help] [--kurtosis-log-level kurtosis_log_level] [--list] [--parallelism parallelism] [--tests test_names] [--test-suite-log-level test_suite_log_level] test_suite_image"
    echo ""
    echo "   --custom-params custom_params_json            JSON string containing arbitrary data that will be passed as-is to your testsuite, so it can modify its behaviour based on input (default: {})"
    echo "   --client-id client_id                         An OAuth client ID which is needed for running Kurtosis in CI, and should be left empty when running Kurtosis on a local machine"
    echo "   --client-secret client_secret                 An OAuth client secret which is needed for running Kurtosis in CI, and should be left empty when running Kurtosis on a local machine"
    echo "   --debug                                       Turns on debug mode, which will: 1) set parallelism == 1 (overriding any other parallelism argument) 2) connect a port on the local machine a port on the testsuite container, for use in running a debugger in the testsuite container 3) bind every used port for every service to a port on the local machine, for making requests to the services"
    echo "   --help                                        Display this message"
    echo "   --kurtosis-log-level kurtosis_log_level       The log level that all output generated by the Kurtosis framework itself should log at (panic|fatal|error|warning|info|debug|trace) (default: info)"
    echo "   --list                                        Rather than running the tests, lists the tests available to run"
    echo "   --parallelism parallelism                     The number of texts to execute in parallel (default: 4)"
    echo "   --tests test_names                            List of test names to run, separated by ',' (default or empty: run all tests)"
    echo "   --test-suite-log-level test_suite_log_level   A string that will be passed as-is to the test suite container to indicate what log level the test suite container should output at; this string should be meaningful to the test suite container because Kurtosis won't know what logging framework the testsuite uses (default: info)"
    echo "   test_suite_image                              The Docker image containing the testsuite to execute"
    
    echo ""
    exit 1  # Exit with an error code, so that if it gets accidentally called in parent scripts/CI it fails loudly
}



# ============================================================================================
#                                      Arg Parsing
# ============================================================================================
client_id=""
client_secret=""
custom_params_json="{}"
do_list="false"
is_debug_mode="false"
kurtosis_log_level="info"
parallelism="4"
show_help="false"
test_names=""
test_suite_image=""
test_suite_log_level="info"



POSITIONAL=()
while [ ${#} -gt 0 ]; do
    key="${1}"
    case "${key}" in
        
        --custom-params)
            
            custom_params_json="${2}"
            shift   # Shift to clear out the flag
            shift   # Shift again to clear out the value
            ;;
        
        --client-id)
            
            client_id="${2}"
            shift   # Shift to clear out the flag
            shift   # Shift again to clear out the value
            ;;
        
        --client-secret)
            
            client_secret="${2}"
            shift   # Shift to clear out the flag
            shift   # Shift again to clear out the value
            ;;
        
        --debug)
            is_debug_mode="true"
            shift   # Shift to clear out the flag
            
            ;;
        
        --help)
            show_help="true"
            shift   # Shift to clear out the flag
            
            ;;
        
        --kurtosis-log-level)
            
            kurtosis_log_level="${2}"
            shift   # Shift to clear out the flag
            shift   # Shift again to clear out the value
            ;;
        
        --list)
            do_list="true"
            shift   # Shift to clear out the flag
            
            ;;
        
        --parallelism)
            
            parallelism="${2}"
            shift   # Shift to clear out the flag
            shift   # Shift again to clear out the value
            ;;
        
        --tests)
            
            test_names="${2}"
            shift   # Shift to clear out the flag
            shift   # Shift again to clear out the value
            ;;
        
        --test-suite-log-level)
            
            test_suite_log_level="${2}"
            shift   # Shift to clear out the flag
            shift   # Shift again to clear out the value
            ;;
        
        -*)
            echo "ERROR: Unrecognized flag '${key}'" >&2
            exit 1
            ;;
        *)
            POSITIONAL+=("${1}")
            shift
            ;;
    esac
done

if "${show_help}"; then
    print_help_and_exit
fi

# Restore positional parameters and assign them to variables
# NOTE: This incantation is the only cross-shell compatiable expansion: https://stackoverflow.com/questions/7577052/bash-empty-array-expansion-with-set-u 
set -- "${POSITIONAL[@]+"${POSITIONAL[@]}"}"
test_suite_image="${1:-}"





# ============================================================================================
#                                    Arg Validation
# ============================================================================================
if [ "${#}" -ne 1 ]; then
    echo "ERROR: Expected 1 positional variables but got ${#}" >&2
    print_help_and_exit
fi

if [ -z "$test_suite_image" ]; then
    echo "ERROR: Variable 'test_suite_image' cannot be empty" >&2
    exit 1
fi



# ============================================================================================
#                                    Main Logic
# ============================================================================================# Because Kurtosis X.Y.Z tags are normalized to X.Y so that minor patch updates are transparently 
#  used, we need to pull the latest API & initializer images
echo "Pulling latest versions of API & initializer image..."
if ! docker pull "${INITIALIZER_IMAGE}"; then
    echo "WARN: An error occurred pulling the latest version of the initializer image (${INITIALIZER_IMAGE}); you may be running an out-of-date version" >&2
else
    echo "Successfully pulled latest version of initializer image"
fi
if ! docker pull "${API_IMAGE}"; then
    echo "WARN: An error occurred pulling the latest version of the API image (${API_IMAGE}); you may be running an out-of-date version" >&2
else
    echo "Successfully pulled latest version of API image"
fi

# Kurtosis needs a Docker volume to store its execution data in
# To learn more about volumes, see: https://docs.docker.com/storage/volumes/
sanitized_image="$(echo "${test_suite_image}" | sed 's/[^a-zA-Z0-9_.-]/_/g')"
suite_execution_volume="$(date +%Y-%m-%dT%H.%M.%S)_${sanitized_image}"
if ! docker volume create "${suite_execution_volume}" > /dev/null; then
    echo "ERROR: Failed to create a Docker volume to store the execution files in" >&2
    exit 1
fi

if ! mkdir -p "${KURTOSIS_DIRPATH}"; then
    echo "ERROR: Failed to create the Kurtosis directory at '${KURTOSIS_DIRPATH}'" >&2
    exit 1
fi

if ! execution_uuid="$(uuidgen)"; then
    echo "ERROR: Failed to generate a UUID for identifying this run of Kurtosis"
    exit 1
fi
execution_uuid="${execution_uuid^^}"

docker run \
    --name "${execution_uuid}__initializer" \
    \
    `# The Kurtosis initializer runs inside a Docker container, but needs to access to the Docker engine; this is how to do it` \
    `# For more info, see the bottom of: http://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/` \
    --mount "type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock" \
    \
    `# Because the Kurtosis initializer runs inside Docker but needs to persist & read files on the host filesystem between execution,` \
    `#  the container expects the Kurtosis directory to be bind-mounted at the special "/kurtosis" path` \
    --mount "type=bind,source=${KURTOSIS_DIRPATH},target=/kurtosis" \
    \
    `# The Kurtosis initializer image requires the volume for storing suite execution data to be mounted at the special "/suite-execution" path` \
    --mount "type=volume,source=${suite_execution_volume},target=/suite-execution" \
    \
    `# The initializer container needs to access the host machine, so it can test for free ports` \
    `# The host machine's IP is available at 'host.docker.internal' in Docker for Windows & Mac by default, but in Linux we need to add this flag to enable it` \
    `# However, non-interactive shells (e.g. CI) will choke on this so we only set it when the user's using debug mode` \
    $(if "${is_debug_mode}"; then echo -n "--add-host=host.docker.internal:host-gateway"; fi) \
    \
    `# Keep these sorted alphabetically` \
    --env CLIENT_ID="${client_id}" \
    --env CLIENT_SECRET="${client_secret}" \
    --env CUSTOM_PARAMS_JSON="${custom_params_json}" \
    --env DO_LIST="${do_list}" \
    --env EXECUTION_UUID="${execution_uuid}" \
    --env IS_DEBUG_MODE="${is_debug_mode}" \
    --env KURTOSIS_API_IMAGE="${API_IMAGE}" \
    --env KURTOSIS_LOG_LEVEL="${kurtosis_log_level}" \
    --env PARALLELISM="${parallelism}" \
    --env SUITE_EXECUTION_VOLUME="${suite_execution_volume}" \
    --env TEST_NAMES="${test_names}" \
    --env TEST_SUITE_IMAGE="${test_suite_image}" \
    --env TEST_SUITE_LOG_LEVEL="${test_suite_log_level}" \
    \
    "${INITIALIZER_IMAGE}"
