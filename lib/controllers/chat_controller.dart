import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jippydriver_driver/constant/constant.dart';
import 'package:jippydriver_driver/constant/send_notification.dart';
import 'package:jippydriver_driver/models/conversation_model.dart';
import 'package:jippydriver_driver/models/inbox_model.dart';
import 'package:jippydriver_driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:jippydriver_driver/services/auth_http_client.dart';

// class ChatController extends GetxController {
//   Rx<TextEditingController> messageController = TextEditingController().obs;
//
//   final ScrollController scrollController = ScrollController();
//
//   @override
//   void onInit() {
//     // TODO: implement onInit
//     if (scrollController.hasClients) {
//       Timer(
//           const Duration(milliseconds: 500),
//           () => scrollController
//               .jumpTo(scrollController.position.maxScrollExtent));
//     }
//     getArgument();
//     super.onInit();
//   }
//
//   RxBool isLoading = true.obs;
//   RxString orderId = "".obs;
//   RxString customerId = "".obs;
//   RxString customerName = "".obs;
//   RxString customerProfileImage = "".obs;
//   RxString restaurantId = "".obs;
//   RxString restaurantName = "".obs;
//   RxString restaurantProfileImage = "".obs;
//   RxString token = "".obs;
//   RxString chatType = "".obs;
//
//   getArgument() {
//     dynamic argumentData = Get.arguments;
//     if (argumentData != null) {
//       orderId.value = argumentData['orderId'];
//       customerId.value = argumentData['customerId'];
//       customerName.value = argumentData['customerName'];
//       customerProfileImage.value = argumentData['customerProfileImage'];
//       restaurantId.value = argumentData['restaurantId'];
//       restaurantName.value = argumentData['restaurantName'];
//       restaurantProfileImage.value = argumentData['restaurantProfileImage'];
//       token.value = argumentData['token'];
//       chatType.value = argumentData['chatType'];
//     }
//     isLoading.value = false;
//   }
//
//   sendMessage(String message, Url? url, String videoThumbnail,
//       String messageType) async {
//     InboxModel inboxModel = InboxModel(
//         lastSenderId: customerId.value,
//         customerId: customerId.value,
//         customerName: customerName.value,
//         restaurantId: restaurantId.value,
//         restaurantName: restaurantName.value,
//         createdAt: Timestamp.now(),
//         orderId: orderId.value,
//         customerProfileImage: customerProfileImage.value,
//         restaurantProfileImage: restaurantProfileImage.value,
//         lastMessage: messageController.value.text,
//         chatType: chatType.value);
//
//     await FireStoreUtils.addDriverInbox(inboxModel);
//
//     ConversationModel conversationModel = ConversationModel(
//         id: const Uuid().v4(),
//         message: message,
//         senderId: restaurantId.value,
//         receiverId: customerId.value,
//         createdAt: Timestamp.now(),
//         url: url,
//         orderId: orderId.value,
//         messageType: messageType,
//         videoThumbnail: videoThumbnail);
//
//     if (url != null) {
//       if (url.mime.contains('image')) {
//         conversationModel.message = "sent a message".tr;
//       } else if (url.mime.contains('video')) {
//         conversationModel.message = "Sent a video".tr;
//       } else if (url.mime.contains('audio')) {
//         conversationModel.message = "Sent a audio".tr;
//       }
//     }
//     await FireStoreUtils.addDriverChat(conversationModel);
//
//     // await SendNotification.sendChatFcmMessage(customerName.value,
//     //     conversationModel.message.toString(), token.value, {});
//   }
//
//   final ImagePicker imagePicker = ImagePicker();
//
// // Future pickFile({required ImageSource source}) async {
// //   try {
// //     XFile? image = await imagePicker.pickImage(source: source);
// //     if (image == null) return;
// //     Url url = await FireStoreUtils.uploadChatImageToFireStorage(File(image.path), Get.context!);
// //     sendMessage('', url, '', 'image');
// //     Get.back();
// //   } on PlatformException catch (e) {
// //     ShowToastDialog.showToast("${"failed_to_pick".tr} : \n $e");
// //   }
// // }
// }
class ChatController extends GetxController {

  RxBool isLoading = true.obs;

  RxString orderId = "".obs;
  RxString chatType = "".obs;
  RxList<ConversationModel> messages = <ConversationModel>[].obs;
  String myId = ""; // store driver uid or restaurant uid
  Rx<TextEditingController> messageController = TextEditingController().obs;
  ScrollController scrollController = ScrollController();
  final ImagePicker imagePicker = ImagePicker();

  @override
  void onInit() {
    super.onInit();
    getArgument();
    fetchChat(); // API fetch
  }


  RxString customerId = "".obs;
  RxString customerName = "".obs;
  RxString customerProfileImage = "".obs;
  RxString restaurantId = "".obs;
  RxString restaurantName = "".obs;
  RxString restaurantProfileImage = "".obs;
  RxString token = "".obs;
  getArgument() {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      orderId.value = argumentData['orderId'];
      customerId.value = argumentData['customerId'];
      customerName.value = argumentData['customerName'];
      customerProfileImage.value = argumentData['customerProfileImage'];
      restaurantId.value = argumentData['restaurantId'];
      restaurantName.value = argumentData['restaurantName'];
      restaurantProfileImage.value = argumentData['restaurantProfileImage'];
      token.value = argumentData['token'];
      chatType.value = argumentData['chatType'];
      myId = argumentData['restaurantId']; // if driver then customerId adjust accordingly
    }
    isLoading.value = false;
  }
  /// ---------------------- API CALL : Fetch Chat ----------------------
  fetchChat() async {
    try {
      isLoading(true);
      final url = Uri.parse("${Constant.baseUrl}chat/$orderId");

      final response = await AuthHttpClient().post(url, body:{
        "chat_type": chatType.value
      });

      final json = jsonDecode(response.body);

      messages.clear();
      for(var m in json["data"]["messages"]){
        messages.add(ConversationModel.fromJson(m));
      }

      Timer(Duration(milliseconds: 400),(){
        if(scrollController.hasClients){
          scrollController.jumpTo(scrollController.position.maxScrollExtent);
        }
      });

    } catch (e) {
      print("CHAT LOAD ERROR => $e");
    } finally {
      isLoading(false);
    }
  }


  sendMessage(String message, Url? url, String videoThumbnail,
      String messageType) async {
    InboxModel inboxModel = InboxModel(
        lastSenderId: customerId.value,
        customerId: customerId.value,
        customerName: customerName.value,
        restaurantId: restaurantId.value,
        restaurantName: restaurantName.value,
        createdAt: Timestamp.now(),
        orderId: orderId.value,
        customerProfileImage: customerProfileImage.value,
        restaurantProfileImage: restaurantProfileImage.value,
        lastMessage: messageController.value.text,
        chatType: chatType.value);

    await FireStoreUtils.addDriverInbox(inboxModel);

    ConversationModel conversationModel = ConversationModel(
        id: const Uuid().v4(),
        message: message,
        senderId: restaurantId.value,
        receiverId: customerId.value,
        createdAt: Timestamp.now(),
        url: url,
        orderId: orderId.value,
        messageType: messageType,
        videoThumbnail: videoThumbnail);

    if (url != null) {
      if (url.mime.contains('image')) {
        conversationModel.message = "sent a message".tr;
      } else if (url.mime.contains('video')) {
        conversationModel.message = "Sent a video".tr;
      } else if (url.mime.contains('audio')) {
        conversationModel.message = "Sent a audio".tr;
      }
    }
    await FireStoreUtils.addDriverChat(conversationModel);

    // await SendNotification.sendChatFcmMessage(customerName.value,
    //     conversationModel.message.toString(), token.value, {});
  }

}
