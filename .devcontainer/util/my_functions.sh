#!/bin/bash
# ======================================================================
#          ------- Custom Functions -------                            #
#  Space for adding custom functions so each repo can customize as.    # 
#  needed.                                                             #
# ======================================================================

customFunction(){
  printInfoSection "This is a custom function that calculates 1 + 1"

  printInfo "1 + 1 = $(( 1 + 1 ))"

}

# Deploy dtpay — backend (backend-services:8080) + frontend (payment-frontend:80) in namespace dtusecase
# Frontend nginx (ConfigMap: frontend-nginx-config) proxies /api → http://backend-services:8080 within the cluster
deployDtpay() {
  printInfoSection "Deploying dtpay: backend (dtdemos-usecase) + frontend (payment-frontend)"
  kubectl create namespace dtusecase 2>/dev/null || true
  kubectl -n dtusecase apply -f "$FRAMEWORK_APPS_PATH/dtpay/manifests/dtpay.yaml"
  waitForAllReadyPods dtusecase
  registerApp "payment-frontend" "dtusecase" "payment-frontend" 80
  printInfo "dtpay deployed. Frontend URL: $(getAppURL payment-frontend)"
}

undeployDtpay() {
  printInfoSection "Undeploying dtpay"
  unregisterApp "payment-frontend" "dtusecase"
  kubectl delete ns dtusecase --force 2>/dev/null || true
}

# Run JMeter load test against dtpay — one-shot Kubernetes Job, auto-deletes after 60s
# Usage: runJmeterTest [version] [app_url]
#   version: v1.0 (default), v1.2, v1.3, v1.4, v2.0
#   app_url: bare hostname to override JVM_APP_URL (e.g. payment-frontend.dtusecase.svc.cluster.local)
#            defaults to auto-detected ingress URL via getAppURL
runJmeterTest() {
  local version="${1:-v1.0}"
  local app_url_override="${2:-}"
  local valid_versions="v1.0 v1.2 v1.3 v1.4 v2.0"

  if ! echo "$valid_versions" | grep -qw "$version"; then
    printWarn "Unknown version '$version'. Valid options: $valid_versions"
    return 1
  fi

  printInfoSection "Running JMeter load test against dtpay (image: domuharahap/jmeter-tester:$version)"

  local target_url
  if [ -n "$app_url_override" ]; then
    target_url="${app_url_override#http://}"
    target_url="${target_url#https://}"
    printInfo "JMeter target URL (override): $target_url"
  else
    target_url=$(getAppURL "payment-frontend" 2>/dev/null || echo "payment-frontend.127.0.0.1.sslip.io")
    # Strip any protocol prefix — JMeter manifest expects a bare hostname
    target_url="${target_url#http://}"
    target_url="${target_url#https://}"
    printInfo "JMeter target URL (auto-detected): $target_url"
  fi

  # A previous stopJmeterTest may still be tearing the namespace down; creating
  # resources in a Terminating namespace fails, so wait for it to disappear first.
  local ns_wait=0
  while [ "$(kubectl get ns jmeter -o jsonpath='{.status.phase}' 2>/dev/null)" = "Terminating" ] && [ $ns_wait -lt 120 ]; do
    [ $ns_wait -eq 0 ] && printInfo "Namespace 'jmeter' is still terminating from a previous run, waiting..."
    sleep 3
    ns_wait=$(( ns_wait + 3 ))
  done
  kubectl get ns jmeter >/dev/null 2>&1 || kubectl create namespace jmeter || return 1

  # Create dynatrace-creds secret in the jmeter namespace from the codespace env vars.
  # DT_ENVIRONMENT and DT_OPERATOR_TOKEN are injected by Codespaces secrets at startup.
  # Secrets are namespace-scoped — the dynatrace namespace secret cannot be read here.

  # Normalize DT_ENVIRONMENT: strip trailing slash, replace .apps.dynatrace.com → .live.dynatrace.com
  local dt_env="${DT_ENVIRONMENT:-}"
  dt_env="${dt_env%/}"
  if echo "$dt_env" | grep -q '\.apps\.dynatrace\.com'; then
    local dt_env_fixed="${dt_env/.apps.dynatrace.com/.live.dynatrace.com}"
    printWarn "DT_ENVIRONMENT uses 'apps' domain — rewriting to 'live': $dt_env_fixed"
    dt_env="$dt_env_fixed"
  fi

  kubectl -n jmeter create secret generic dynatrace-creds \
    --from-literal="DT_ENVIRONMENT=${dt_env}" \
    --from-literal="DT_OPERATOR_TOKEN=${DT_OPERATOR_TOKEN:-}" \
    --dry-run=client -o yaml | kubectl apply -f - || return 1

  # Delete any prior run and wait until its pod is gone, so the wait loop below
  # cannot latch onto the old (Terminating) pod.
  kubectl delete job jmeter-tester -n jmeter --ignore-not-found --wait=true --timeout=150s

  # Patch image and env vars locally before applying — Job spec.template is immutable
  # once created, so all overrides must be baked in before the first kubectl apply.
  local manifest="$FRAMEWORK_APPS_PATH/jmeter-tester/manifests/jmeter-job.yaml"
  kubectl set image --local -f "$manifest" \
    jmeter-tester="domuharahap/jmeter-tester:$version" -o yaml \
    | kubectl set env --local -f - JVM_APP_URL="$target_url" -o yaml \
    | kubectl apply -n jmeter -f - || { printWarn "Failed to submit the JMeter job"; return 1; }

  printInfo "JMeter job submitted (version $version, target: $target_url). Waiting for pod to start..."

  waitForPod jmeter jmeter-tester

  local pod_name
  pod_name=$(kubectl get pod -n jmeter -l app=jmeter-tester --sort-by=.metadata.creationTimestamp \
    -o jsonpath='{range .items[?(@.metadata.deletionTimestamp==null)]}{.metadata.name}{"\n"}{end}' 2>/dev/null | tail -n1)
  printInfo "JMeter test started (pod: ${pod_name:-unknown}, target: $target_url)"
  printInfo "Follow logs: kubectl logs -n jmeter $pod_name --follow"
  printInfo "Stop test:   stopJmeterTest"
  printInfo "The job will auto-delete 60s after completion."
}

stopJmeterTest() {
  printInfoSection "Stopping JMeter test"
  kubectl delete job jmeter-tester -n jmeter --ignore-not-found --wait=true --timeout=150s 2>/dev/null || true
  kubectl delete ns jmeter --ignore-not-found --wait=true --timeout=150s 2>/dev/null || true
}





