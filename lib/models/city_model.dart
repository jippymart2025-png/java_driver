class CityModel {
  int? cityId;
  String? cityName;

  CityModel({this.cityId, this.cityName});

  CityModel.fromJson(Map<String, dynamic> json) {
    cityId = json['cityId'];
    cityName = json['cityName'];
  }
}