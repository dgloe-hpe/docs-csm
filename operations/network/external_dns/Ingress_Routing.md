## Ingress Routing

Ingress routing to services via Istio’s ingress gateway is configured by VirtualService custom resource definitions \(CRD\). When using external hostnames, there needs to be a VirtualService CRD that matches the external hostname to the desired destination.

For example, the configuration below controls the ingress routing for prometheus.rocket.dev.cray.com:

```bash
ncn-w001# kubectl get vs -n sysmgmt-health cray-sysmgmt-health-prometheus
NAME                             GATEWAYS                      HOSTS                              AGE
cray-sysmgmt-health-prometheus   [services/services-gateway]   [prometheus.rocket.dev.cray.com]   22h

ncn-w001# kubectl get vs -n sysmgmt-health cray-sysmgmt-health-prometheus -o yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  creationTimestamp: "2020-07-09T17:49:07Z"
  generation: 1
  labels:
    app: cray-sysmgmt-health-prometheus
    app.kubernetes.io/instance: cray-sysmgmt-health
    app.kubernetes.io/managed-by: Tiller
    app.kubernetes.io/name: cray-sysmgmt-health
    app.kubernetes.io/version: 8.15.4
    helm.sh/chart: cray-sysmgmt-health-0.3.1
  name: cray-sysmgmt-health-prometheus
  namespace: sysmgmt-health
  resourceVersion: "41620"
  selfLink: /apis/networking.istio.io/v1beta1/namespaces/sysmgmt-health/virtualservices/cray-sysmgmt-health-prometheus
  uid: d239dfcc-a827-4a51-9b73-6eccfb937088
spec:
  gateways:
  - services/services-gateway
  hosts:
  - prometheus.rocket.dev.cray.com
  http:
  - match:
    - authority:
        exact: prometheus.rocket.dev.cray.com
    route:
    - destination:
        host: cray-sysmgmt-health-promet-prometheus
        port:
          number: 9090

```

By matching the external hostname in the authority field, Istio’s ingress gateway is able to route incoming traffic from Keycloak Gatekeeper to the `cray-sysmgmt-health-prometheus` service in the `sysmgmt-health` namespace. Also, notice that the VirtualService for prometheus.rocket.dev.cray.com uses the existing `services/services-gateway` Gateway CRD and does not create a new one.

### Secure Ingress via Keycloak Gatekeeper

Web apps intended to be accessed via the browser, such as Prometheus, Alertmanager, Grafana, Kiali, Jaeger, Kibana, Elasticsearch, should go through the Keycloak Gatekeeper reverse proxy. Browser sessions are automatically configured to use a JSON Web Token \(JWT\) for authorization to Istio’s ingress gateway, enabling a central enforcement point of Open Policy Agent \(OPA\) policies for system management traffic.

The Keycloak Gatekeeper will inject HTTP headers so that an upstream endpoint can identify the user and customize access as needed. To enable ingress via Keycloak Gatekeeper external hostnames, web apps need to be added to the `keycloak_gatekeeper_proxied_hosts` Ansible variable.

