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

# TODO TODO TESTING
KURTOSIS_CORE_TAG="mieubrisse_network-partitioning"
KURTOSIS_DOCKERHUB_ORG="kurtosistech"
INITIALIZER_IMAGE="${KURTOSIS_DOCKERHUB_ORG}/kurtosis-core_initializer:${KURTOSIS_CORE_TAG}"
API_IMAGE="${KURTOSIS_DOCKERHUB_ORG}/kurtosis-core_api:${KURTOSIS_CORE_TAG}"

POSITIONAL_ARG_DEFINITION_FRAGMENTS=2



# ============================================================================================
#                                      Arg Parsing
# ============================================================================================
function print_help_and_exit() {
    echo ""
    echo "$(basename "${0}") [--custom-env-vars custom_env_vars_json] [--client-id client_id] [--client-secret client_secret] [--help] [--kurtosis-log-level kurtosis_log_level] [--list] [--parallelism parallelism] [--tests test_names] [--test-suite-log-level test_suite_log_level] test_suite_image"
    echo ""
    echo "   --custom-env-vars custom_env_vars_json        JSON containing key-value mappings of custom environment variables that will be passed through to the Dockerfile of the test suite container, e.g. '{"MY_VAR": "/some/value"}' (default: {})"
    echo "   --client-id client_id                         An OAuth client ID which is needed for running Kurtosis in CI, and should be left empty when running Kurtosis on a local machine"
    echo "   --client-secret client_secret                 An OAuth client secret which is needed for running Kurtosis in CI, and should be left empty when running Kurtosis on a local machine"
    echo "   --help                                        Display this message"
    echo "   --kurtosis-log-level kurtosis_log_level       The log level that all output generated by the Kurtosis framework itself should log at (trace|debug|info|warn|error|fatal) (default: info)"
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
custom_env_vars_json="{}"
do_list="false"
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
        
        --custom-env-vars)
            
            custom_env_vars_json="${2}"
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
            echo "Error: Unrecognized flag '${key}'" >&2
            exit 1
            ;;
        *)
            POSITIONAL+=("${1}")
            shift
            ;;
    esac
done

# Restore positional parameters and assign them to variables
set -- "${POSITIONAL[@]}"
test_suite_image="$1"


if "${show_help}"; then
    print_help_and_exit
fi



# ============================================================================================
#                                    Arg Validation
# ============================================================================================
if [ "${#}" -ne 1 ]; then
    echo "Error: Expected 1 positional variables but got ${#}" >&2
    print_help_and_exit
fi

if [ -z "$test_suite_image" ]; then
    echo "Error: Variable 'test_suite_image' cannot be empty" >&2
    exit 1
fi



# ============================================================================================
#                                    Main Logic
# ============================================================================================
# Kurtosis needs a Docker volume to store its execution data in
# To learn more about volumes, see: https://docs.docker.com/storage/volumes/
sanitized_image="$(echo "${test_suite_image}" | sed 's/[^a-zA-Z0-9_.-]/_/g')"
suite_execution_volume="$(date +%Y-%m-%dT%H.%M.%S)_${sanitized_image}"
if ! docker volume create "${suite_execution_volume}" > /dev/null; then
    echo "Error: Failed to create a Docker volume to store the execution files in" >&2
    exit 1
fi

if ! mkdir -p "${KURTOSIS_DIRPATH}"; then
    echo "Error: Failed to create the Kurtosis directory at '${KURTOSIS_DIRPATH}'" >&2
    exit 1
fi

docker run \
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
    `# Keep these sorted alphabetically` \
    --env CLIENT_ID="${client_id}" \
    --env CLIENT_SECRET="${client_secret}" \
    --env CUSTOM_ENV_VARS_JSON="${custom_env_vars_json}" \
    --env DO_LIST="${do_list}" \
    --env KURTOSIS_API_IMAGE="${API_IMAGE}" \
    --env KURTOSIS_LOG_LEVEL="${kurtosis_log_level}" \
    --env PARALLELISM="${parallelism}" \
    --env SUITE_EXECUTION_VOLUME="${suite_execution_volume}" \
    --env TEST_NAMES="${test_names}" \
    --env TEST_SUITE_IMAGE="${test_suite_image}" \
    --env TEST_SUITE_LOG_LEVEL="${test_suite_log_level}" \
    \
    "${INITIALIZER_IMAGE}"
