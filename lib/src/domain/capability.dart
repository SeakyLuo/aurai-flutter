enum CapabilityAvailability {
  available,
  unavailable,
  permissionRequired,
  unsupported,
}

class Capability {
  const Capability({
    required this.id,
    required this.name,
    required this.availability,
    required this.reason,
  });

  final String id;
  final String name;
  final CapabilityAvailability availability;
  final String reason;

  bool get isAvailable => availability == CapabilityAvailability.available;
}
