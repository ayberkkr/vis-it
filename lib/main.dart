import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const VisitApp());
}

class VisitApp extends StatelessWidget {
  const VisitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Vis'it",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: const Color(0xFFFAF8F5), // Kemik Beyazı
        primaryColor: const Color(0xFF3E2723), // Espresso Kahve
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4E342E),
          background: const Color(0xFFFAF8F5),
        ),
      ),
      home: const HomePage(),
    );
  }
}

// GEZGİN VERİ MODELİ
class CurrentUser {
  static bool isLoggedIn = false;
  static String userId = ""; 
  static String fullName = "Misafir Kullanıcı";
}

/// ==========================================
/// 1. ANASAYFA EKRANI
/// ==========================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Karşılama Alanı
            Padding(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("YENİ YERLER KEŞFET", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Color(0xFF7D6B60))),
                      const SizedBox(height: 4),
                      const Text("Sıradaki Rota?", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFF2D1B11), height: 1.1)),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage())).then((_) {
                        setState(() {});
                      });
                    },
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFF4E342E),
                      child: Text(
                        CurrentUser.isLoggedIn ? CurrentUser.fullName[0].toUpperCase() : "M",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  )
                ],
              ),
            ),

            // Arama Çubuğu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => searchQuery = value.trim().toLowerCase()),
                style: const TextStyle(color: Color(0xFF2D1B11)),
                decoration: InputDecoration(
                  hintText: "Şehir veya kategori ara...",
                  hintStyle: const TextStyle(color: Color(0xFF9E8E85)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF6D594F)),
                  suffixIcon: searchQuery.isNotEmpty 
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFF6D594F)),
                          onPressed: () => setState(() {
                            searchQuery = "";
                            _searchController.clear();
                          }),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF0EAE3),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
            ),

            if (searchQuery.isEmpty) ...[
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildQuickMenuButton(Icons.account_balance, "Müzeler"),
                    _buildQuickMenuButton(Icons.fort, "Tarihi Mekanlar"),
                    _buildQuickMenuButton(Icons.restaurant, "Gurme Rotalar"),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Text("Popüler Şehirler", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D1B11))),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 110,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildPopularCityCard("Bursa", "16", "bursa", const Color(0xFFEDE4DC)),
                    _buildPopularCityCard("İstanbul", "34", "istanbul", const Color(0xFFE5E7E9)),
                    _buildPopularCityCard("İzmir", "35", "izmir", const Color(0xFFEAE5E2)),
                    _buildPopularCityCard("Antalya", "07", "antalya", const Color(0xFFE2EAE5)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Text("Şehir Listesi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D1B11))),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('cities').orderBy('plate').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Center(child: Text("Veri yüklenirken hata oluştu."));
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                  final docs = snapshot.data!.docs;
                  
                  final filteredDocs = docs.where((doc) {
                    final cityName = doc['name'].toString().toLowerCase();
                    final List<dynamic> places = doc['places'] ?? [];
                    bool matchCategory = places.any((p) {
                      String cat = p['category'].toString().toLowerCase();
                      if (searchQuery == "müzeler" || searchQuery == "müze") return cat.contains("müze");
                      if (searchQuery == "tarihi mekanlar" || searchQuery == "tarih") return cat == "tarih" || cat == "doğa";
                      if (searchQuery == "gurme rotalar" || searchQuery == "gastronomi") return cat == "gastronomi";
                      return false;
                    });
                    return cityName.contains(searchQuery) || matchCategory;
                  }).toList();

                  if (filteredDocs.isEmpty) return const Center(child: Text("Aramanıza uygun sonuç bulunamadı."));

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: filteredDocs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final cityData = filteredDocs[index].data() as Map<String, dynamic>;
                      return Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEFEAE4))),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: const Color(0xFFF5EFEB), borderRadius: BorderRadius.circular(12)),
                            child: Text(cityData['plate'] ?? "00", style: const TextStyle(color: Color(0xFF4A3B32), fontWeight: FontWeight.bold)),
                          ),
                          title: Text(cityData['name'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D1B11))),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF8C7A6B)),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => CityPlacesPage(cityData: cityData, cityId: filteredDocs[index].id)));
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            
            if (searchQuery.isEmpty && !isKeyboardOpen) _buildTravelTipPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularCityCard(String name, String plate, String cityId, Color bgColor) {
    return GestureDetector(
      onTap: () async {
        final doc = await FirebaseFirestore.instance.collection('cities').doc(cityId).get();
        if (doc.exists && mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => CityPlacesPage(cityData: doc.data()!, cityId: cityId)));
        }
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0D5CB))),
        child: Stack(
          children: [
            Positioned(right: -5, bottom: -15, child: Text(plate, style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: const Color(0xFF4A3B32).withOpacity(0.08)))),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D1B11))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickMenuButton(IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ElevatedButton.icon(
        onPressed: () {
          setState(() {
            searchQuery = label.toLowerCase();
            _searchController.text = label;
          });
        },
        icon: Icon(icon, size: 16, color: const Color(0xFF4E342E)),
        label: Text(label, style: const TextStyle(color: Color(0xFF2D1B11), fontSize: 12, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFEFEAE4))),
        ),
      ),
    );
  }

  Widget _buildTravelTipPanel() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF2D1B11), borderRadius: BorderRadius.circular(16)),
      child: const Row(
        children: [
          Icon(Icons.lightbulb, color: Colors.amber, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Günün Seyahat Tavsiyesi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 4),
                Text("Müzekart alarak Türkiye genelindeki 300'den fazla resmi müzeyi tüm yıl ücretsiz ziyaret edebileceğinizi biliyor muydunuz?", style: TextStyle(color: Color(0xFFDCD6D0), fontSize: 11)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

/// ==========================================
/// 2. KATEGORİ VE MEKAN SÜZME EKRANI (GÖRSEL DESTEKLİ)
/// ==========================================
class CityPlacesPage extends StatefulWidget {
  final Map<String, dynamic> cityData;
  final String cityId;
  const CityPlacesPage({super.key, required this.cityData, required this.cityId});

  @override
  State<CityPlacesPage> createState() => _CityPlacesPageState();
}

class _CityPlacesPageState extends State<CityPlacesPage> {
  final List<String> categories = ["Tümü", "Tarihi Mekanlar", "Müzeler", "Gurme Rotalar"];
  String selectedCategory = "Tümü";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cityData['name'] ?? "", style: const TextStyle(color: Color(0xFF2D1B11), fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF0EAE3),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D1B11)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4E342E),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
        onPressed: () {
          if (!CurrentUser.isLoggedIn) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.orange, content: Text("Mekan eklemek için lütfen önce üye girişi gerçekleştiriniz.")));
          } else {
            _showAddPlaceDialog(context);
          }
        },
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('cities').doc(widget.cityId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final currentCityData = snapshot.data!.data() as Map<String, dynamic>;
          final List<dynamic> allPlaces = currentCityData['places'] ?? [];
          
          final approvedPlaces = allPlaces.where((place) {
            final isApp = place['isApproved'];
            return isApp == null || isApp == true;
          }).toList();

          var filteredPlaces = approvedPlaces.where((place) {
            String dbCategory = place['category'].toString().toLowerCase();
            String dbName = place['name'].toString().toLowerCase();

            if (selectedCategory == "Tümü") return true;
            if (selectedCategory == "Tarihi Mekanlar") return dbCategory == "tarih" || dbCategory == "doğa" || dbCategory == "tarihi mekanlar";
            if (selectedCategory == "Müzeler") return dbCategory == "müze" || dbCategory == "müzeler" || dbName.contains("müze");
            if (selectedCategory == "Gurme Rotalar") return dbCategory == "gastronomi" || dbCategory == "gurme rotalar";
            return false;
          }).toList();

          filteredPlaces.sort((a, b) => (b['avgRating'] ?? 5.0).compareTo(a['avgRating'] ?? 5.0));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (_) => setState(() => selectedCategory = category),
                        selectedColor: const Color(0xFF6D594F),
                        labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF2D1B11), fontWeight: FontWeight.bold),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 20.0, top: 10, bottom: 10),
                child: Text("Önerilen Rotalar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D1B11))),
              ),
              Expanded(
                child: filteredPlaces.isEmpty
                    ? const Center(child: Text("Bu kategoride henüz lokasyon eklenmemiş."))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredPlaces.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final place = filteredPlaces[index];
                          String placeId = place['name'].toString().toLowerCase().replaceAll(' ', '_');
                          double rating = (place['avgRating'] ?? 5.0).toDouble();
                          String? imgPath = place['imagePath'];
                          
                          return Container(
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEFEAE4))),
                            child: ListTile(
                              // KANKA LİSTEYE ŞIK GÖRSEL ÖNİZLEME DESTEĞİ EKLEDİK
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: imgPath != null && imgPath.isNotEmpty && !imgPath.startsWith('http')
                                    ? Image.file(File(imgPath), width: 50, height: 50, fit: BoxFit.cover)
                                    : Container(
                                        width: 50, height: 50, 
                                        color: const Color(0xFFF0EAE3), 
                                        child: const Icon(Icons.image, color: Color(0xFF8C7A6B), size: 20)
                                      ),
                              ),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(place['name'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D1B11)), overflow: TextOverflow.ellipsis)),
                                  Row(
                                    children: [
                                      const Icon(Icons.star, color: Colors.amber, size: 16),
                                      const SizedBox(width: 4),
                                      Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF4E342E))),
                                    ],
                                  )
                                ],
                              ),
                              subtitle: Text(
                                place['category'] == 'tarih' || place['category'] == 'doğa' ? 'Tarihi Mekanlar' :
                                place['category'] == 'gastronomi' ? 'Gurme Rotalar' : place['category'], 
                                style: const TextStyle(color: Color(0xFF8C7A6B), fontSize: 13)
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF8C7A6B)),
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => PlaceDetailPage(placeData: place, cityId: widget.cityId, placeId: placeId)));
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddPlaceDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String categorySelection = "Tarihi Mekanlar";
    File? placeImage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF8F5),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> _getPlaceImage() async {
              final picker = ImagePicker();
              final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40);
              if (pickedFile != null) setModalState(() => placeImage = File(pickedFile.path));
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Yeni Lokasyon Önerisi", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D1B11))),
                    const SizedBox(height: 16),
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Mekan Adı", border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: categorySelection,
                      decoration: const InputDecoration(labelText: "Kategori", border: OutlineInputBorder()),
                      items: ["Tarihi Mekanlar", "Müzeler", "Gurme Rotalar"].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setModalState(() => categorySelection = val ?? "Tarihi Mekanlar"),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: "Açıklama", border: OutlineInputBorder())),
                    const SizedBox(height: 16),
                    
                    // KANKA FOTOĞRAF ZORUNLULUĞU PANELİ
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _getPlaceImage,
                          icon: const Icon(Icons.camera_alt, color: Colors.white),
                          label: const Text("Mekan Fotoğrafı Ekle (Zorunlu)", style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D594F)),
                        ),
                        const SizedBox(width: 12),
                        if (placeImage != null) const Icon(Icons.check_circle, color: Colors.green)
                      ],
                    ),
                    if (placeImage != null) ...[
                      const SizedBox(height: 10),
                      ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(placeImage!, height: 100, width: double.infinity, fit: BoxFit.cover)),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: placeImage == null ? Colors.grey : const Color(0xFF4E342E), 
                        minimumSize: const Size(double.infinity, 50)
                      ),
                      // Fotoğraf yoksa tetiğe basılamıyor kurumsal kural kanka
                      onPressed: placeImage == null ? null : () async {
                        if (nameCtrl.text.isEmpty || descCtrl.text.isEmpty) return;

                        if (ReviewModerator.hasBadWords(descCtrl.text) || ReviewModerator.hasBadWords(nameCtrl.text)) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text("İçerikte uygunsuz kelime saptandı!")));
                          return;
                        }

                        // KANKA YAPAY ZEKAYLA GÖRSEL DOĞRULAMA (MOCK AI ANALYZER COPLUGU)
                        bool isAIValid = AIImageAnalyzer.isValidStructure(placeImage!, nameCtrl.text);
                        if (!isAIValid) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text("Yapay Zeka Analizi Başarısız: Seçilen fotoğraf belirtilen konumu doğrulamıyor!")));
                          return;
                        }

                        final newPlaceMap = {
                          "name": nameCtrl.text,
                          "category": categorySelection,
                          "description": descCtrl.text,
                          "lat": 40.18, "lng": 29.06,
                          "avgRating": 5.0,
                          "isApproved": false,
                          "imagePath": placeImage!.path,
                          "suggestedBy": CurrentUser.userId // Profilde otomatik listelemek için dökümanı bağlıyoruz
                        };

                        await FirebaseFirestore.instance.collection('cities').doc(widget.cityId).update({
                          "places": FieldValue.arrayUnion([newPlaceMap])
                        });

                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Öneriniz inceleme ekibimize başarıyla iletilmiştir.")));
                      },
                      child: const Text("Yeri Onaya Gönder", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// ==========================================
/// 3. MEKAN DETAY SAYFASI (GÖRSEL ALANLI SÜRÜM)
/// ==========================================
class PlaceDetailPage extends StatelessWidget {
  final Map<String, dynamic> placeData;
  final String cityId;
  final String placeId;
  PlaceDetailPage({super.key, required this.placeData, required this.cityId, required this.placeId});

  final _commentController = TextEditingController();

  String _getSmartMaskedName(String originalName) {
    if (CurrentUser.isLoggedIn && CurrentUser.fullName.toLowerCase() == originalName.toLowerCase()) {
      return "$originalName (Sen)"; 
    }
    if (originalName.isEmpty) return "Anonim Gezgin";
    List<String> parts = originalName.split(' ');
    String masked = "";
    for (var part in parts) {
      if (part.isNotEmpty) masked += "${part[0]}${'*' * (part.length - 1)} ";
    }
    return masked.trim();
  }

  Future<void> _openMap(double lat, double lng) async {
    final String googleMapsUrl = "geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(placeData['name'] ?? 'Mekan')})";
    final Uri url = Uri.parse(googleMapsUrl);
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    bool isMuseum = placeData['category'].toString().toLowerCase().contains('müze') || placeData['name'].toString().toLowerCase().contains('müze');
    String? mainImg = placeData['imagePath'];
    int selectedRatingInBuild = 5;

    return Scaffold(
      appBar: AppBar(
        title: Text(placeData['name'] ?? "", style: const TextStyle(color: Color(0xFF2D1B11), fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF0EAE3),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D1B11)),
      ),
      body: StatefulBuilder(
        builder: (context, setReviewState) {
          Future<void> submitReviewLocal() async {
            if (!CurrentUser.isLoggedIn) return;
            if (_commentController.text.isEmpty) return;

            if (ReviewModerator.hasBadWords(_commentController.text)) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text("Yorum içeriğinde uygunsuz ifadeler saptandı!")));
              return;
            }

            // KANKA SİSTEM OTOMATİK OLARAK BURAYA DA USERID BASIYOR Kİ PROFİLDE SÜZÜLSÜN
            await FirebaseFirestore.instance.collection('cities').doc(cityId).collection('places').doc(placeId).collection('reviews').add({
              'userId': CurrentUser.userId,
              'userName': CurrentUser.fullName, 
              'comment': _commentController.text,
              'rating': selectedRatingInBuild,
              'createdAt': Timestamp.now(),
              'placeName': placeData['name']
            });

            _commentController.clear();
            setReviewState(() => selectedRatingInBuild = 5);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // KANKA LOKASYONUN ANA GÖRSEL ALANI
                if (mainImg != null && mainImg.isNotEmpty && !mainImg.startsWith('http')) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(File(mainImg), height: 200, width: double.infinity, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 16),
                ],
                
                Text(placeData['name'] ?? "", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D1B11))),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFFDCD6D0), thickness: 1.5),
                const SizedBox(height: 12),

                if (isMuseum) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFF0EAE3), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0D5CB))),
                    child: const Text("Giriş Ücreti: 60 TL (T.C. Kültür Bakanlığı Müzekart Geçerlidir)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF2D1B11))),
                  ),
                  const SizedBox(height: 16),
                ],

                const Text("Açıklama", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D1B11))),
                const SizedBox(height: 8),
                Text(placeData['description'] ?? "", style: const TextStyle(fontSize: 16, color: Color(0xFF5C4D43), height: 1.6)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => _openMap((placeData['lat'] as num).toDouble(), (placeData['lng'] as num).toDouble()),
                  icon: const Icon(Icons.map, color: Colors.white),
                  label: const Text("Haritada Göster", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D594F), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),

                const SizedBox(height: 32),
                const Text("Gezgin Değerlendirmeleri", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D1B11))),
                const SizedBox(height: 12),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('cities').doc(cityId).collection('places').doc(placeId).collection('reviews').orderBy('createdAt', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text("Henüz değerlendirme yapılmamış. İlk yorumu siz yazın!"));
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final review = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_getSmartMaskedName(review['userName'] ?? ""), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D1B11))),
                                    Row(children: List.generate(review['rating'] ?? 5, (i) => const Icon(Icons.star, color: Colors.amber, size: 16))),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(review['comment'] ?? "", style: const TextStyle(color: Color(0xFF5C4D43))),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 24),
                const Divider(color: Color(0xFFDCD6D0)),
                const SizedBox(height: 16),
                
                Text(CurrentUser.isLoggedIn ? "Deneyimini Paylaş" : "Yorum Yazmak İçin Giriş Yapmalısınız 🔒", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D1B11))),
                const SizedBox(height: 12),
                if (CurrentUser.isLoggedIn) ...[
                  TextField(controller: _commentController, maxLines: 3, decoration: const InputDecoration(labelText: "Yorumunuz...", border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Puanınız:", style: TextStyle(fontWeight: FontWeight.bold)),
                      DropdownButton<int>(
                        value: selectedRatingInBuild,
                        items: List.generate(5, (i) => DropdownMenuItem(value: i + 1, child: Text("${i + 1} Yıldız"))),
                        onChanged: (val) => setReviewState(() => selectedRatingInBuild = val ?? 5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: submitReviewLocal,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D1B11), minimumSize: const Size(double.infinity, 50)),
                    child: const Text("Yorumu Gönder", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// ==========================================
/// 👤 4. FIRESTORE TABANLI GELİŞMİŞ DASHBOARD PROFİL SAYFASI
/// ==========================================
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController();
  String authMethod = "Mail";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gezgin Profili", style: TextStyle(color: Color(0xFF2D1B11), fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF0EAE3),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D1B11)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: CurrentUser.isLoggedIn ? _buildProfileDashboard() : _buildRegisterForm(),
      ),
    );
  }

  Widget _buildRegisterForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Vis'it Dünyasına Katıl", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF2D1B11))),
          const SizedBox(height: 4),
          const Text("Kayıt işlemlerinizin ardından seyahat verileriniz güvenle saklanacaktır.", style: TextStyle(color: Color(0xFF7D6B60), fontSize: 13)),
          const SizedBox(height: 24),
          
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Adınız Soyadınız", border: OutlineInputBorder())),
          const SizedBox(height: 16),
          
          Row(
            children: [
              const Text("Doğrulama Tercihi:", style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              ChoiceChip(
                label: const Text("E-Mail"), 
                selected: authMethod == "Mail",
                onSelected: (_) => setState(() => authMethod = "Mail"),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text("Telefon"), 
                selected: authMethod == "Telefon",
                onSelected: (_) => setState(() => authMethod = "Telefon"),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contactController, 
            decoration: InputDecoration(labelText: authMethod == "Mail" ? "E-Posta Adresiniz" : "Telefon Numaranız", border: const OutlineInputBorder())
          ),
          const SizedBox(height: 16),
          TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: "Şifreniz", border: OutlineInputBorder())),
          const SizedBox(height: 24),
          
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4E342E), minimumSize: const Size(double.infinity, 50)),
            child: const Text("Hesap Oluştur ve Giriş Yap", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              if (_nameController.text.isEmpty || _contactController.text.isEmpty || _passwordController.text.isEmpty) return;

              if (ReviewModerator.hasBadWords(_nameController.text)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text("İçerikte uygunsuz kelime saptandı!")));
                return;
              }

              final userDoc = await FirebaseFirestore.instance.collection('users').add({
                'fullName': _nameController.text.trim(),
                'contact': _contactController.text.trim(),
                'authMethod': authMethod,
                'createdAt': Timestamp.now()
              });

              setState(() {
                CurrentUser.isLoggedIn = true;
                CurrentUser.userId = userDoc.id;
                CurrentUser.fullName = _nameController.text.trim();
              });

              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kaydınız veritabanı sunucularına başarıyla işlendi.")));
            },
          )
        ],
      ),
    );
  }

  // KANKA YENİ EFSANE PROFİL DASHBOARDU
  Widget _buildProfileDashboard() {
    final listInputController = TextEditingController();

    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 28, backgroundColor: const Color(0xFF6D594F), child: Text(CurrentUser.fullName[0].toUpperCase(), style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold))),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(CurrentUser.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D1B11))),
                    const Text("Doğrulanmış Gezgin", style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.red),
                onPressed: () => setState(() {
                  CurrentUser.isLoggedIn = false;
                  CurrentUser.fullName = "Misafir Kullanıcı";
                  CurrentUser.userId = "";
                }),
              )
            ],
          ),
          const SizedBox(height: 20),
          
          // SEKMELİ COPLUK ALANI
          const TabBar(
            isScrollable: true,
            labelColor: Color(0xFF2D1B11),
            indicatorColor: Color(0xFF4E342E),
            tabs: [
              Tab(text: "Eklediğim Noktalar"),
              Tab(text: "Değerlendirmelerim"),
              Tab(text: "Gezilen Yerler"),
              Tab(text: "Gezilecek Yerler"),
            ],
          ),
          const SizedBox(height: 12),
          
          Expanded(
            child: TabBarView(
              children: [
                // 1. SİSTEM OTOMATİK: KULLANICININ ÖNERDİĞİ MEKANLAR
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('cities').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    List<String> suggestedPlaces = [];
                    for (var cityDoc in snapshot.data!.docs) {
                      final data = cityDoc.data() as Map<String, dynamic>;
                      final List<dynamic> places = data['places'] ?? [];
                      for (var p in places) {
                        if (p['suggestedBy'] == CurrentUser.userId) {
                          suggestedPlaces.add("${p['name']} (${data['name']})");
                        }
                      }
                    }
                    if (suggestedPlaces.isEmpty) return const Center(child: Text("Henüz bir lokasyon önerisinde bulunmadınız.", style: TextStyle(fontSize: 12)));
                    return ListView.builder(
                      itemCount: suggestedPlaces.length,
                      itemBuilder: (context, i) => ListTile(leading: const Icon(Icons.location_on, size: 18), title: Text(suggestedPlaces[i], style: const TextStyle(fontSize: 14))),
                    );
                  },
                ),

                // 2. SİSTEM OTOMATİK: KULLANICININ YAPTIĞI YORUMLAR
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collectionGroup('reviews').where('userId', isEqualTo: CurrentUser.userId).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) return const Center(child: Text("Henüz bir değerlendirme yazmadınız.", style: TextStyle(fontSize: 12)));
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final r = docs[i].data() as Map<String, dynamic>;
                        return ListTile(
                          leading: const Icon(Icons.comment, size: 18),
                          title: Text(r['comment'] ?? "", style: const TextStyle(fontSize: 14)),
                          subtitle: Text(r['placeName'] ?? "Mekan", style: const TextStyle(fontSize: 11)),
                        );
                      },
                    );
                  },
                ),

                // 3. KULLANICI ÖZGÜR: GEZİLEN YERLER LİSTESİ
                _buildUserEditableList('visited_places', listInputController, "Gezdiğiniz bir yer ekleyin..."),

                // 4. KULLANICI ÖZGÜR: GEZİLECEK YERLER LİSTESİ
                _buildUserEditableList('target_places', listInputController, "Gezilecek bir yer hedefi ekleyin..."),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildUserEditableList(String collectionName, TextEditingController ctrl, String hint) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: TextField(controller: ctrl, decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(fontSize: 13)))),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Color(0xFF4E342E)),
              onPressed: () async {
                if (ctrl.text.isEmpty) return;
                await FirebaseFirestore.instance.collection('users').doc(CurrentUser.userId).collection(collectionName).add({
                  'title': ctrl.text.trim(),
                  'createdAt': Timestamp.now()
                });
                ctrl.clear();
              },
            )
          ],
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(CurrentUser.userId).collection(collectionName).orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final items = snapshot.data!.docs;
              if (items.isEmpty) return const Center(child: Text("Listeniz henüz boş.", style: TextStyle(fontSize: 12)));
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) {
                  return ListTile(
                    title: Text(items[i]['title'] ?? "", style: const TextStyle(fontSize: 14)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      onPressed: () => items[i].reference.delete(),
                    ),
                  );
                },
              );
            },
          ),
        )
      ],
    );
  }
}

/// ==========================================
/// 🛑 5. KÜFÜR ENGELLEME SINIFI
/// ==========================================
class ReviewModerator {
  static final List<String> _badWords = [
    "yarrak", "sik", "pipi", "amcık", "göt", "orospu", "piç", "siktir", 
    "amk", "aq", "pezevenk", "kahpe", "yavşak", "ibne"
  ];

  static bool hasBadWords(String text) {
    String cleanedText = text.toLowerCase().trim();
    for (var word in _badWords) {
      if (cleanedText.contains(word)) return true;
    }
    return false;
  }
}

/// ==========================================
/// 🧠 6. MOCK YAPAY ZEKA GÖRSEL ANALİZ MOTORU
/// ==========================================
class AIImageAnalyzer {
  static bool isValidStructure(File imageFile, String placeName) {
    // Kanka Yapay Zeka departmanına yakışır simülasyon: Çok küçük boyutlu veya boş isimli yapıları eliyoruz
    int sizeInBytes = imageFile.lengthSync();
    if (sizeInBytes < 5000) return false; // Boş/Geçersiz görsel koruması
    
    String normalizedName = placeName.toLowerCase();
    // Sahte/Alakasız gönderimleri önlemek amacıyla başlık kontrol simülasyonu kanka
    if (normalizedName.length < 3) return false;
    
    return true; // Görsel yapısı geçerli
  }
}