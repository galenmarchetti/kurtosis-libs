# This script regenerates Go bindings corresponding to the .proto files that define the API container's API
# It requires the Golang Protobuf extension to the 'protoc' compiler, as well as the Golang gRPC extension

set -euo pipefail
script_dirpath="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
root_dirpath="$(dirname "${script_dirpath}")"

# ================================ CONSTANTS =======================================================
GO_MOD_FILENAME="go.mod"
GO_MOD_FILE_MODULE_KEYWORD="module"


LIB_DIRNAME="lib"
API_DIRNAME="core_api"
BINDINGS_DIRNAME="bindings"

# =============================== MAIN LOGIC =======================================================
go_mod_filepath="${root_dirpath}/${GO_MOD_FILENAME}"
if ! [ -f "${go_mod_filepath}" ]; then
    echo "Error: Could not get Go module name; no ${GO_MOD_FILENAME} found in root of repo" >&2
    exit 1
fi
go_module="$(grep "^${GO_MOD_FILE_MODULE_KEYWORD}" "${go_mod_filepath}" | awk '{print $2}')"
if [ "${go_module}" == "" ]; then
    echo "Error: Could not extract Go module from ${go_mod_filepath}" >&2
    exit 1
fi
api_bindings_go_pkg="${go_module}/${LIB_DIRNAME}/${BINDINGS_DIRNAME}"

api_dirpath="${root_dirpath}/${LIB_DIRNAME}/${API_DIRNAME}"
input_dirpath="${api_dirpath}"
output_dirpath="${api_dirpath}/${BINDINGS_DIRNAME}"

if [ "${output_dirpath}/" != "/" ]; then
    if ! find ${output_dirpath} -name '*.go' -delete; then
        echo "Error: An error occurred removing the existing protobuf-generated code" >&2
        exit 1
    fi
else
    echo "Error: output dirpath must not be empty!" >&2
    exit 1
fi

for protobuf_filepath in $(find "${input_dirpath}" -name "*.proto"); do
    protobuf_filename="$(basename "${protobuf_filepath}")"

    # NOTE: When multiple people start developing on this, we won't be able to rely on using the user's local protoc because they might differ. We'll need to standardize by:
    #  1) Using protoc inside the API container Dockerfile to generate the output Go files (standardizes the output files for Docker)
    #  2) Using the user's protoc to generate the output Go files on the local machine, so their IDEs will work
    #  3) Tying the protoc inside the Dockerfile and the protoc on the user's machine together using a protoc version check
    #  4) Adding the locally-generated Go output files to .gitignore
    #  5) Adding the locally-generated Go output files to .dockerignore (since they'll get generated inside Docker)
    if ! protoc \
            -I="${input_dirpath}" \
            --go_out="plugins=grpc:${output_dirpath}" \
            `# Rather than specify the go_package in source code (which means all consumers of these protobufs would get it),` \
            `#  we specify the go_package here per https://developers.google.com/protocol-buffers/docs/reference/go-generated` \
            `# See also: https://github.com/golang/protobuf/issues/1272` \
            --go_opt="M${protobuf_filename}=${api_bindings_go_pkg};$(basename "${api_bindings_go_pkg}")" \
            "${protobuf_filepath}"; then
        echo "Error: An error occurred generating lib core files from protobuf file: ${protobuf_filepath}" >&2
        exit 1
    fi
done
