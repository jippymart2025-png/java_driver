class StateModel {
  final int stateId;
  final String stateName;

  StateModel({
    required this.stateId,
    required this.stateName,
  });

  factory StateModel.fromJson(Map<String, dynamic> json) {
    return StateModel(
      stateId: json['stateId'] ?? 0,
      stateName: json['stateName'] ?? '',
    );
  }
}