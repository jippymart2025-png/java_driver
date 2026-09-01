import 'dart:io';
import 'package:jippydriver_driver/controllers/edit_profile_controller.dart';
import 'package:jippydriver_driver/models/zone_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/themes/app_them_data.dart';
import 'package:jippydriver_driver/themes/responsive.dart';
import 'package:jippydriver_driver/themes/text_field_widget.dart';
import 'package:jippydriver_driver/utils/dark_theme_provider.dart';
import 'package:jippydriver_driver/utils/network_image_widget.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<EditProfileController>(
        init: Get.isRegistered<EditProfileController>()
            ? Get.find<EditProfileController>()
            : EditProfileController(),
        builder: (controller) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: themeChange.getThem()
                  ? AppThemeData.grey900
                  : AppThemeData.grey50,
              centerTitle: false,
              titleSpacing: 0,
              title: Text(
                "Edit Profile".tr,
                style: TextStyle(
                    color: themeChange.getThem()
                        ? AppThemeData.grey50
                        : AppThemeData.grey900,
                    fontSize: 18,
                    fontFamily: AppThemeData.medium),
              ),
            ),
            body: controller.isLoading.value
                ? Center(child: Constant.loader())
                : SingleChildScrollView(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          // ========================================================
                          // PROFILE IMAGE
                          // ========================================================

                          ClipRRect(
                            borderRadius: BorderRadius.circular(60),
                            child: controller.profileImage.value.isEmpty
                                ? Image.asset(
                              Constant.userPlaceHolder,
                              height: Responsive.width(24, context),
                              width: Responsive.width(24, context),
                              fit: BoxFit.cover,
                            )
                                : Constant().hasValidUrl(
                              controller.profileImage.value,
                            )
                                ? NetworkImageWidget(
                              fit: BoxFit.cover,
                              imageUrl:
                              controller.profileImage.value,
                              height:
                              Responsive.width(24, context),
                              width:
                              Responsive.width(24, context),
                            )
                                : Image.file(
                              File(
                                controller.profileImage.value,
                              ),
                              height:
                              Responsive.width(24, context),
                              width:
                              Responsive.width(24, context),
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (context, error, stackTrace) {
                                return Image.asset(
                                  Constant.userPlaceHolder,
                                  height:
                                  Responsive.width(
                                    24,
                                    context,
                                  ),
                                  width:
                                  Responsive.width(
                                    24,
                                    context,
                                  ),
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                          ),

                          // ========================================================
                          // EDIT BUTTON
                          // ========================================================

                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: () {
                                buildBottomSheet(
                                  context,
                                  controller,
                                );
                              },
                              child: SvgPicture.asset(
                                "assets/icons/ic_edit.svg",
                              ),
                            ),
                          ),

                          // ========================================================
                          // UPLOAD LOADING
                          // ========================================================

                          if (controller.isUploadingProfileImage.value)
                            Positioned.fill(
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black45,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),                    const SizedBox(
                      height: 40,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFieldWidget(
                            title: 'First Name'.tr,
                            controller: controller.firstNameController.value,
                            hintText: 'First Name'.tr,
                          ),
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: TextFieldWidget(
                            title: 'Last Name'.tr,
                            controller: controller.lastNameController.value,
                            hintText: 'Last Name'.tr,
                          ),
                        ),
                      ],
                    ),
                    TextFieldWidget(
                      title: 'Email'.tr,
                      textInputType: TextInputType.emailAddress,
                      controller: controller.emailController.value,
                      hintText: 'Email'.tr,
                      enable: false,
                    ),
                    TextFieldWidget(
                      title: 'Phone Number'.tr,
                      textInputType: TextInputType.emailAddress,
                      controller: controller.phoneNumberController.value,
                      hintText: 'Phone Number'.tr,
                      enable: false,
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Zone".tr,
                            style: TextStyle(
                                fontFamily: AppThemeData.semiBold,
                                fontSize: 14,
                                color: themeChange.getThem()
                                    ? AppThemeData.grey100
                                    : AppThemeData.grey800)),
                        const SizedBox(
                          height: 5,
                        ),
                        DropdownButtonFormField<String>(
                            hint: Text(
                              'Select zone'.tr,
                              style: TextStyle(
                                fontSize: 14,
                                color: themeChange.getThem()
                                    ? AppThemeData.grey700
                                    : AppThemeData.grey700,
                                fontFamily: AppThemeData.regular,
                              ),
                            ),
                            icon: const Icon(Icons.keyboard_arrow_down),
                            decoration: InputDecoration(
                              errorStyle: const TextStyle(color: Colors.red),
                              isDense: true,
                              filled: true,
                              fillColor: themeChange.getThem()
                                  ? AppThemeData.grey900
                                  : AppThemeData.grey50,
                              disabledBorder: UnderlineInputBorder(
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(10)),
                                borderSide: BorderSide(
                                    color: themeChange.getThem()
                                        ? AppThemeData.grey900
                                        : AppThemeData.grey50,
                                    width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(10)),
                                borderSide: BorderSide(
                                    color: themeChange.getThem()
                                        ? AppThemeData.secondary300
                                        : AppThemeData.secondary300,
                                    width: 1),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(10)),
                                borderSide: BorderSide(
                                    color: themeChange.getThem()
                                        ? AppThemeData.grey900
                                        : AppThemeData.grey50,
                                    width: 1),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(10)),
                                borderSide: BorderSide(
                                    color: themeChange.getThem()
                                        ? AppThemeData.grey900
                                        : AppThemeData.grey50,
                                    width: 1),
                              ),
                              border: OutlineInputBorder(
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(10)),
                                borderSide: BorderSide(
                                    color: themeChange.getThem()
                                        ? AppThemeData.grey900
                                        : AppThemeData.grey50,
                                    width: 1),
                              ),
                            ),
                            value: () {
                              final selectedId =
                                  controller.selectedZone.value.id?.toString();
                              if (selectedId == null || selectedId.isEmpty) {
                                return null;
                              }
                              final hasSelected = controller.zoneList.any(
                                (z) => z.id?.toString() == selectedId,
                              );
                              return hasSelected ? selectedId : null;
                            }(),
                            onChanged: (zoneId) {
                              if (zoneId == null || zoneId.isEmpty) return;
                              final idx = controller.zoneList.indexWhere(
                                (z) => z.id?.toString() == zoneId,
                              );
                              if (idx >= 0) {
                                controller.selectedZone.value =
                                    controller.zoneList[idx];
                              }
                            },
                            style: TextStyle(
                                fontSize: 14,
                                color: themeChange.getThem()
                                    ? AppThemeData.grey50
                                    : AppThemeData.grey900,
                                fontFamily: AppThemeData.medium),
                            items: (() {
                              final uniqueById = <String, ZoneModel>{};
                              for (final zone in controller.zoneList) {
                                final id = zone.id?.toString() ?? '';
                                if (id.isEmpty) continue;
                                uniqueById.putIfAbsent(id, () => zone);
                              }
                              return uniqueById.entries.map((entry) {
                                return DropdownMenuItem<String>(
                                  value: entry.key,
                                  child: Text(entry.value.name?.toString() ?? ''),
                                );
                              }).toList();
                            })()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: SafeArea(
              child: InkWell(
                onTap: () async {
                  controller.saveData();
                },
                child: Container(
                  color: AppThemeData.driverApp300,
                  width: Responsive.width(100, context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      "Save".tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: themeChange.getThem()
                            ? AppThemeData.grey50
                            : AppThemeData.grey50,
                        fontSize: 16,
                        fontFamily: AppThemeData.medium,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        });
  }

  buildBottomSheet(BuildContext context, EditProfileController controller) {
    return showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SizedBox(
              height: Responsive.height(22, context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 15),
                    child: Text("please select".tr,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            IconButton(
                                onPressed: () => controller.pickFile(
                                    source: ImageSource.camera),
                                icon: const Icon(
                                  Icons.camera_alt,
                                  size: 32,
                                )),
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                "camera".tr,
                                style: const TextStyle(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: () => controller.pickFile(
                                  source: ImageSource.gallery),
                              icon: const Icon(
                                Icons.photo_library_sharp,
                                size: 32,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                "gallery".tr,
                                style: const TextStyle(),
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
