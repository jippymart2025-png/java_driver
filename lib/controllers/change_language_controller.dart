import 'dart:convert';

import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/models/language_model.dart';
import 'package:jippydriver_driver/utils/fire_store_utils.dart';
import 'package:jippydriver_driver/utils/preferences.dart';
import 'package:get/get.dart';

import '../constant/collection_name.dart';
import 'package:jippydriver_driver/services/auth_http_client.dart';

class ChangeLanguageController extends GetxController {
  Rx<LanguageModel> selectedLanguage = LanguageModel().obs;
  RxList<LanguageModel> languageList = <LanguageModel>[].obs;
  RxBool isLoading = true.obs;

  @override
  void onInit() {
    getLanguage();
    super.onInit();
  }

  getLanguage() async {
    try {
      isLoading.value = true;
      final response = await AuthHttpClient().get(Uri.parse("${Constant.baseUrl}settings/languages"));
      if (response.statusCode == 200) {
        final Map<String, dynamic> res = json.decode(response.body);

        if (res['success'] == true && res['data'] != null) {
          languageList.clear();
          // Assuming the API now returns a single object, wrap it in a list
          var languageData = res['data'];
          LanguageModel languageModel = LanguageModel.fromJson(languageData);
          languageList.add(languageModel);
          // Set selected language from preferences
          if (Preferences.getString(Preferences.languageCodeKey).toString().isNotEmpty) {
            LanguageModel pref = Constant.getLanguage();
            for (var element in languageList) {
              if (element.slug == pref.slug) {
                selectedLanguage.value = element;
              }
            }
          }
        }
      } else {
        print("Failed to fetch languages: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching languages: $e");
    } finally {
      isLoading.value = false;
    }
  }

}
