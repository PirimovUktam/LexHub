import 'package:lexhub/core/legal_safety/pii_anonymizer.dart';
import 'package:lexhub/features/legal_talk/data/models/talk_message_model.dart';
import 'package:lexhub/features/legal_talk/data/models/talk_room_model.dart';
import 'package:lexhub/features/legal_talk/domain/entities/talk_message.dart';
import 'package:uuid/uuid.dart';

abstract class LegalTalkLocalDataSource {
  Future<List<TalkRoomModel>> getRooms({String? category, String? searchQuery});
  Future<List<TalkMessageModel>> getRoomMessages(String roomId);
  Future<TalkMessageModel> sendMessage({
    required String roomId,
    required String senderName,
    required TalkSenderRole senderRole,
    required String messageText,
    bool isAudioMessage = false,
    String? audioDuration,
  });
  Future<TalkMessageModel> toggleLike({
    required String roomId,
    required String messageId,
  });
  Future<TalkRoomModel> createRoom({
    required String title,
    required String category,
    required String description,
  });
}

class LegalTalkLocalDataSourceImpl implements LegalTalkLocalDataSource {
  static final List<TalkRoomModel> _seedRooms = [
    TalkRoomModel(
      id: 'room_1',
      title: "🔴 Jonli Munozara: Yangi tahrirdagi Mehnat qonunchiligi amalda",
      category: "Mehnat",
      description:
          "Ish beruvchilarning noqonuniy talablari, majburiy mehnat, sinov muddati va ishdan bo'shatish kompensatsiyalari bo'yicha jonli savol-javob.",
      participantsCount: 142,
      activeNowCount: 28,
      isLive: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    TalkRoomModel(
      id: 'room_2',
      title: "🚗 Haydovchilar va YPX: Huquqingizni bilasizmi?",
      category: "Haydovchilar",
      description:
          "Xizmat guvohnomasini talab qilish, to'xtatish sabablari, radar jarimalariga e'tiroz va videoga olish huquqi bo'yicha tajriba almashish.",
      participantsCount: 89,
      activeNowCount: 15,
      isLive: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),
    TalkRoomModel(
      id: 'room_3',
      title: "⚖️ Advokat bilan ochiq minbar (Savol-Javob)",
      category: "Advokat bilan",
      description:
          "Fuqarolik ishlari, aliment undirish, meros taqsimoti, mulk oldi-sotdisi bo'yicha litsenziyaga ega advokatlarning bepul huquqiy tushuntirishlari.",
      participantsCount: 210,
      activeNowCount: 45,
      isLive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    TalkRoomModel(
      id: 'room_4',
      title: "☕ Erkin Huquqiy Gurung (Umumiy xona)",
      category: "Erkin",
      description:
          "Kundalik turmushdagi yuridik savollar, bank kreditlari, onlayn do'konlardan qaytarish va iste'molchi huquqlari bo'yicha erkin muloqot maydoni.",
      participantsCount: 65,
      activeNowCount: 8,
      isLive: false,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  static final Map<String, List<TalkMessageModel>> _seedMessages = {
    'room_1': [
      TalkMessageModel(
        id: 'msg_1_pin',
        roomId: 'room_1',
        senderName: "Huquqchi Moderator",
        senderRole: TalkSenderRole.moderator,
        messageText:
            "Xush kelibsiz! Ushbu xonada barcha ishtirokchilar va advokatlar real vaqtda fikr almashadi. Shaxsiy ma'lumotlar (telefon, pasport) Privacy Guard orqali avtomat yashiriladi.",
        timestamp: DateTime.now().subtract(const Duration(minutes: 50)),
        likesCount: 34,
        isPinned: true,
      ),
      TalkMessageModel(
        id: 'msg_1_1',
        roomId: 'room_1',
        senderName: "Dilnoza Rahimova",
        senderRole: TalkSenderRole.citizen,
        messageText:
            "Assalomu alaykum! Ish beruvchi sinov muddati uchun ish haqi to'lamaymiz deyapti. Bu qanchalik qonuniy?",
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
        likesCount: 6,
      ),
      TalkMessageModel(
        id: 'msg_1_2',
        roomId: 'room_1',
        senderName: "Advokat Jamshid Qodirov",
        senderRole: TalkSenderRole.verifiedLawyer,
        messageText:
            "Mutlaqo noqonuniy! Mehnat kodeksining 131-moddasiga binoan dastlabki sinov davrida xodimga to'liq qonuniy ish haqi to'lanishi shart. Tegishli shartnoma tuzilmagan bo'lsa ham Mehnat inspeksiyasiga (1092) murojaat qilish huquqingiz bor.",
        timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
        likesCount: 28,
        isLikedByMe: true,
      ),
      TalkMessageModel(
        id: 'msg_1_3',
        roomId: 'room_1',
        senderName: "Sardor Aliyev",
        senderRole: TalkSenderRole.citizen,
        messageText:
            "Men ham shunday holatga tushgandim, ariza berganimdan keyin 3 kun ichida to'lab berishgan.",
        timestamp: DateTime.now().subtract(const Duration(minutes: 14)),
        likesCount: 4,
      ),
      TalkMessageModel(
        id: 'msg_1_4',
        roomId: 'room_1',
        senderName: "Advokat Jamshid Qodirov",
        senderRole: TalkSenderRole.verifiedLawyer,
        messageText:
            "Mehnat nizolari bo'yicha sudga da'vo muddati 1 oy ekanligini unutmang! Kechiktirmasdan harakat qiling.",
        timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
        likesCount: 19,
      ),
      TalkMessageModel(
        id: 'msg_1_5',
        roomId: 'room_1',
        senderName: "Malika Yusupova",
        senderRole: TalkSenderRole.citizen,
        messageText:
            "Rahmat katta, juda foydali ma'lumot bo'ldi!",
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
        likesCount: 2,
      ),
    ],
    'room_2': [
      TalkMessageModel(
        id: 'msg_2_pin',
        roomId: 'room_2',
        senderName: "Huquqchi Moderator",
        senderRole: TalkSenderRole.moderator,
        messageText:
            "Haydovchilar diqqatiga: YPX xodimi bilan muloqotda o'zingizni xotirjam tuting va audio/videoga olish qonuniy kafolatlangan.",
        timestamp: DateTime.now().subtract(const Duration(minutes: 40)),
        likesCount: 18,
        isPinned: true,
      ),
      TalkMessageModel(
        id: 'msg_2_1',
        roomId: 'room_2',
        senderName: "Farrux Zokirov",
        senderRole: TalkSenderRole.citizen,
        messageText:
            "YPX xodimi hujjat tekshirish uchun to'xtatganda, uning xizmat guvohnomasini talab qilishga haqlimanmi?",
        timestamp: DateTime.now().subtract(const Duration(minutes: 32)),
        likesCount: 11,
      ),
      TalkMessageModel(
        id: 'msg_2_2',
        roomId: 'room_2',
        senderName: "Advokat Bobur Mirzayev",
        senderRole: TalkSenderRole.verifiedLawyer,
        messageText:
            "Ha, albatta! Vazirlar Mahkamasining 975-son qaroriga asosan xodim o'zini tanishtirishi va haydovchi talabiga binoan xizmat guvohnomasini ochib ko'rsatishi shart.",
        timestamp: DateTime.now().subtract(const Duration(minutes: 26)),
        likesCount: 31,
        isLikedByMe: true,
      ),
      TalkMessageModel(
        id: 'msg_2_3',
        roomId: 'room_2',
        senderName: "Advokat Bobur Mirzayev",
        senderRole: TalkSenderRole.verifiedLawyer,
        messageText:
            "Audio tushuntirish: Haydovchi mashinadan tushmasdan guvohnomani videoga qayd etish qoidalari.",
        timestamp: DateTime.now().subtract(const Duration(minutes: 22)),
        likesCount: 24,
        isAudioMessage: true,
        audioDuration: "0:45",
      ),
      TalkMessageModel(
        id: 'msg_2_4',
        roomId: 'room_2',
        senderName: "Otabek",
        senderRole: TalkSenderRole.citizen,
        messageText:
            "Radar jarimasi 10 kun ichida 50% chegirma bilan to'lanishi mumkin, to'g'rimi?",
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        likesCount: 5,
      ),
      TalkMessageModel(
        id: 'msg_2_5',
        roomId: 'room_2',
        senderName: "Advokat Bobur Mirzayev",
        senderRole: TalkSenderRole.verifiedLawyer,
        messageText:
            "To'g'ri, 15 kun ichida 50% chegirmali to'lov imtiyozi amal qiladi.",
        timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
        likesCount: 15,
      ),
    ],
    'room_3': [
      TalkMessageModel(
        id: 'msg_3_pin',
        roomId: 'room_3',
        senderName: "Huquqchi Moderator",
        senderRole: TalkSenderRole.moderator,
        messageText:
            "Ochiq minbar: Advokatlarga to'g'ridan-to'g'ri savol yo'llang. Xabarlar anonimlashtiriladi.",
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        likesCount: 42,
        isPinned: true,
      ),
      TalkMessageModel(
        id: 'msg_3_1',
        roomId: 'room_3',
        senderName: "Shahnoza Karimova",
        senderRole: TalkSenderRole.citizen,
        messageText:
            "Aliment to'lashdan bo'yin tovlayotgan sobiq turmush o'rtog'ini qanday javobgarlikka tortish mumkin?",
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        likesCount: 9,
      ),
      TalkMessageModel(
        id: 'msg_3_2',
        roomId: 'room_3',
        senderName: "Advokat Nargiza Karimova",
        senderRole: TalkSenderRole.verifiedLawyer,
        messageText:
            "Aliment bo'yicha 2 oydan ortiq qarzdorlik bo'lsa, MIB orqali ma'muriy qamoq (15 sutkagacha) yoki Jinoyat kodeksining 122-moddasi bilan jinoiy javobgarlik choralari qo'llaniladi.",
        timestamp: DateTime.now().subtract(const Duration(minutes: 24)),
        likesCount: 39,
        isLikedByMe: true,
      ),
      TalkMessageModel(
        id: 'msg_3_3',
        roomId: 'room_3',
        senderName: "Advokat Nargiza Karimova",
        senderRole: TalkSenderRole.verifiedLawyer,
        messageText:
            "Ovozli maslahat: Chet elga chiqishni cheklash va MIBga talabnoma yuborish tartibi.",
        timestamp: DateTime.now().subtract(const Duration(minutes: 18)),
        likesCount: 22,
        isAudioMessage: true,
        audioDuration: "1:15",
      ),
      TalkMessageModel(
        id: 'msg_3_4',
        roomId: 'room_3',
        senderName: "Nodirbek",
        senderRole: TalkSenderRole.citizen,
        messageText:
            "Meros bo'yicha notariusga 6 oy ichida ariza berish shartmi?",
        timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
        likesCount: 8,
      ),
      TalkMessageModel(
        id: 'msg_3_5',
        roomId: 'room_3',
        senderName: "Advokat Nargiza Karimova",
        senderRole: TalkSenderRole.verifiedLawyer,
        messageText:
            "Ha, Fuqarolik kodeksi 1146-moddasiga ko'ra meros ochilgan kundan boshlab 6 oy ichida notariusga murojaat qilinishi shart.",
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        likesCount: 16,
      ),
    ],
    'room_4': [
      TalkMessageModel(
        id: 'msg_4_pin',
        roomId: 'room_4',
        senderName: "Huquqchi Moderator",
        senderRole: TalkSenderRole.moderator,
        messageText:
            "Erkin gurung xonasi: Madaniy va huquqiy muloqot qoidalariga rioya qiling.",
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        likesCount: 12,
        isPinned: true,
      ),
      TalkMessageModel(
        id: 'msg_4_1',
        roomId: 'room_4',
        senderName: "Jasur",
        senderRole: TalkSenderRole.citizen,
        messageText:
            "Onlayn do'kondan kiyim buyurtma qilgandim, o'lchami to'g'ri kelmadi. Qaytarib berish muddati qancha?",
        timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
        likesCount: 7,
      ),
      TalkMessageModel(
        id: 'msg_4_2',
        roomId: 'room_4',
        senderName: "Ulug'bek",
        senderRole: TalkSenderRole.citizen,
        messageText:
            "Iste'molchilar huquqlarini himoya qilish qonuniga ko'ra 10 kun ichida almashtirish yoki pulni qaytarib olish huquqiga egasiz.",
        timestamp: DateTime.now().subtract(const Duration(minutes: 35)),
        likesCount: 14,
      ),
      TalkMessageModel(
        id: 'msg_4_3',
        roomId: 'room_4',
        senderName: "Advokat Jamshid Qodirov",
        senderRole: TalkSenderRole.verifiedLawyer,
        messageText:
            "Bunda kiyimning tovar ko'rinishi, yorliqlari va to'lov cheki saqlangan bo'lishi talab etiladi.",
        timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
        likesCount: 18,
      ),
      TalkMessageModel(
        id: 'msg_4_4',
        roomId: 'room_4',
        senderName: "Jasur",
        senderRole: TalkSenderRole.citizen,
        messageText: "Tushundim, rahmat kattakon!",
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        likesCount: 3,
      ),
    ],
  };

  final List<TalkRoomModel> _rooms = List.from(_seedRooms);
  final Map<String, List<TalkMessageModel>> _messages = Map.from(_seedMessages);

  @override
  Future<List<TalkRoomModel>> getRooms({String? category, String? searchQuery}) async {
    List<TalkRoomModel> result = List.from(_rooms);

    if (category != null && category.isNotEmpty && category != "Barchasi") {
      result = result.where((r) => r.category == category).toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      result = result
          .where((r) =>
              r.title.toLowerCase().contains(q) ||
              r.description.toLowerCase().contains(q) ||
              r.category.toLowerCase().contains(q))
          .toList();
    }

    return result;
  }

  @override
  Future<List<TalkMessageModel>> getRoomMessages(String roomId) async {
    return List.from(_messages[roomId] ?? []);
  }

  @override
  Future<TalkMessageModel> sendMessage({
    required String roomId,
    required String senderName,
    required TalkSenderRole senderRole,
    required String messageText,
    bool isAudioMessage = false,
    String? audioDuration,
  }) async {
    // Sanitize PII automatically
    final sanitizedText = PiiAnonymizer.anonymize(messageText);

    final newMessage = TalkMessageModel(
      id: const Uuid().v4(),
      roomId: roomId,
      senderName: senderName,
      senderRole: senderRole,
      messageText: sanitizedText,
      timestamp: DateTime.now(),
      likesCount: 0,
      isAudioMessage: isAudioMessage,
      audioDuration: audioDuration,
      isLikedByMe: false,
    );

    if (!_messages.containsKey(roomId)) {
      _messages[roomId] = [];
    }
    _messages[roomId]!.add(newMessage);

    // Update active participants count in room
    final roomIdx = _rooms.indexWhere((r) => r.id == roomId);
    if (roomIdx != -1) {
      final old = _rooms[roomIdx];
      _rooms[roomIdx] = old.copyWith(
        participantsCount: old.participantsCount + 1,
      ) as TalkRoomModel;
    }

    return newMessage;
  }

  @override
  Future<TalkMessageModel> toggleLike({
    required String roomId,
    required String messageId,
  }) async {
    final list = _messages[roomId];
    if (list == null) {
      throw Exception("Xona topilmadi");
    }

    final idx = list.indexWhere((m) => m.id == messageId);
    if (idx == -1) {
      throw Exception("Xabar topilmadi");
    }

    final old = list[idx];
    final isLikedNow = !old.isLikedByMe;
    final updated = TalkMessageModel(
      id: old.id,
      roomId: old.roomId,
      senderName: old.senderName,
      senderRole: old.senderRole,
      messageText: old.messageText,
      timestamp: old.timestamp,
      likesCount: old.likesCount + (isLikedNow ? 1 : -1),
      isPinned: old.isPinned,
      isAudioMessage: old.isAudioMessage,
      audioDuration: old.audioDuration,
      isLikedByMe: isLikedNow,
    );

    list[idx] = updated;
    return updated;
  }

  @override
  Future<TalkRoomModel> createRoom({
    required String title,
    required String category,
    required String description,
  }) async {
    final sanitizedTitle = PiiAnonymizer.anonymize(title);
    final sanitizedDesc = PiiAnonymizer.anonymize(description);

    final newRoom = TalkRoomModel(
      id: const Uuid().v4(),
      title: sanitizedTitle,
      category: category,
      description: sanitizedDesc,
      participantsCount: 1,
      activeNowCount: 1,
      isLive: true,
      createdAt: DateTime.now(),
    );

    _rooms.insert(0, newRoom);

    // Initialize with a welcome moderator message
    _messages[newRoom.id] = [
      TalkMessageModel(
        id: const Uuid().v4(),
        roomId: newRoom.id,
        senderName: "Huquqchi Moderator",
        senderRole: TalkSenderRole.moderator,
        messageText:
            "Ushbu munozara xonasi yangi ochildi. Huquqiy fikringiz yoki savollaringizni erkin bayon qiling!",
        timestamp: DateTime.now(),
        likesCount: 1,
        isPinned: true,
      ),
    ];

    return newRoom;
  }
}
