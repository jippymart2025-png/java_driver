class AreaModel {
  int? areaId;
  String? areaName;

  AreaModel({
    this.areaId,
    this.areaName,
  });

  AreaModel.fromJson(Map<String, dynamic> json) {
    areaId = json['areaId'];
    areaName = json['areaName'];
  }
}