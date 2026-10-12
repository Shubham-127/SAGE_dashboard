/// One microservice (one "shop" in the pizza-chain picture).
class ServiceInfo {
  final String name; // e.g. "order-service"
  final int port; // e.g. 8081
  final double baseLatency; // normal response time in milliseconds
  final List<String> dependsOn; // which services THIS one calls
  final List<double> latency = []; // last 30 readings -> drawn as the little chart

  ServiceInfo(this.name, this.port, this.baseLatency, this.dependsOn);
}
