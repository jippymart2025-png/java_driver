import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:jippydriver_driver/app/chat_screens/chat_screen.dart';
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/constant/show_toast_dialog.dart';
import 'package:jippydriver_driver/models/inbox_model.dart';
import 'package:jippydriver_driver/models/user_model.dart';
import 'package:jippydriver_driver/themes/app_them_data.dart';
import 'package:jippydriver_driver/themes/responsive.dart';
import 'package:jippydriver_driver/utils/dark_theme_provider.dart';
import 'package:jippydriver_driver/utils/network_image_widget.dart';
import 'package:jippydriver_driver/utils/fire_store_utils.dart';
import 'package:provider/provider.dart';

class DriverInboxScreen extends StatelessWidget {
  const DriverInboxScreen({super.key});

  Future<List<InboxModel>> fetchChats() async {
    final restaurantId = FireStoreUtils.getCurrentUid();
    final url = Uri.parse('${Constant.baseUrl}get-chats?restaurant_id=$restaurantId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        List<InboxModel> chats = (data['chats'] as List)
            .map((chat) => InboxModel.fromJson(chat))
            .toList();
        return chats;
      } else {
        return [];
      }
    } else {
      throw Exception('Failed to load chats');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);

    return Scaffold(
      body: FutureBuilder<List<InboxModel>>(
        future: fetchChats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: Constant.loader());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error loading chats"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Constant.showEmptyView(message: "No Conversation found".tr);
          }

          final chats = snapshot.data!;

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final inboxModel = chats[index];

              return InkWell(
                onTap: () async {
                  ShowToastDialog.showLoader("Please wait".tr);

                  UserModel? customer = await FireStoreUtils.getUserProfile(
                      inboxModel.customerId.toString());
                  UserModel? restaurantUser = await FireStoreUtils.getUserProfile(
                      inboxModel.restaurantId.toString());
                  ShowToastDialog.closeLoader();

                  Get.to(const ChatScreen(), arguments: {
                    "customerName": '${customer!.fullName}',
                    "restaurantName": restaurantUser!.fullName,
                    "orderId": inboxModel.orderId,
                    "restaurantId": restaurantUser.id,
                    "customerId": customer.id,
                    "customerProfileImage": customer.profilePictureURL ?? "",
                    "restaurantProfileImage":
                    restaurantUser.profilePictureURL ?? "",
                    "token": restaurantUser.fcmToken,
                    "chatType": inboxModel.chatType,
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  child: Container(
                    decoration: ShapeDecoration(
                      color: themeChange.getThem()
                          ? AppThemeData.grey900
                          : AppThemeData.grey50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.all(Radius.circular(10)),
                            child: NetworkImageWidget(
                              imageUrl: inboxModel.customerProfileImage ?? "",
                              fit: BoxFit.cover,
                              height: Responsive.height(6, context),
                              width: Responsive.width(12, context),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "${inboxModel.customerName}",
                                        textAlign: TextAlign.start,
                                        style: TextStyle(
                                          fontFamily: AppThemeData.semiBold,
                                          fontSize: 16,
                                          color: themeChange.getThem()
                                              ? AppThemeData.grey100
                                              : AppThemeData.grey800,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      Constant.timestampToDate(inboxModel.createdAt!),
                                      textAlign: TextAlign.start,
                                      style: TextStyle(
                                        fontFamily: AppThemeData.regular,
                                        fontSize: 16,
                                        color: themeChange.getThem()
                                            ? AppThemeData.grey400
                                            : AppThemeData.grey500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  "${inboxModel.lastMessage}",
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontFamily: AppThemeData.medium,
                                    fontSize: 14,
                                    color: themeChange.getThem()
                                        ? AppThemeData.grey200
                                        : AppThemeData.grey700,
                                  ),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
