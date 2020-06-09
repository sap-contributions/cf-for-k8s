#!/bin/bash -eu

export KUBECONFIG=kube-config.yml
cluster_name=$(cat pool-lock/name)
echo ${GCP_SERVICE_ACCOUNT_JSON} > gcp-service-account.json
gcloud auth activate-service-account --key-file=gcp-service-account.json --project=${GCP_PROJECT_NAME} >/dev/null 2>&1
gcloud container clusters get-credentials "${cluster_name}" --zone ${GCP_PROJECT_ZONE} >/dev/null 2>&1

DNS_DOMAIN="${cluster_name}.k8s-dev.relint.rocks"

if [[ "${UPGRADE}" == "true" ]]; then
  echo "Copying bosh vars store from latest release install"
  mkdir -p "/tmp/${cluster_name}.k8s-dev.relint.rocks"
  cp env-metadata/cf-vars.yaml "/tmp/${cluster_name}.k8s-dev.relint.rocks/cf-vars.yaml"
  echo "Generating install values using cf-vars from fresh install..."
else
  echo "Generating install values..."
fi
cf-for-k8s-candidate/hack/generate-values.sh --cf-domain "${DNS_DOMAIN}" --gcr-service-account-json gcp-service-account.json > cf-values.yml
echo "istio_static_ip: $(jq -r '.lb_static_ip' pool-lock/metadata)" >> cf-values.yml

echo "Installing CF..."
kapp deploy -a cf -f <(ytt -f cf-for-k8s-candidate/config -f cf-values.yml) -y

bosh interpolate --path /cf_admin_password cf-values.yml > env-metadata/cf-admin-password.txt
echo "${DNS_DOMAIN}" > env-metadata/dns-domain.txt
cp "/tmp/${cluster_name}.k8s-dev.relint.rocks/cf-vars.yaml" env-metadata
