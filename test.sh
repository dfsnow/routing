eval "$(jq -r ".package_versions | to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]" config.json)"

echo $python_major
