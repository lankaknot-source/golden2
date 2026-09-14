import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'find_caregiver_view_model.dart';
import '../../domain/model/data_models.dart';
import '../widgets/glass_container.dart';

const Color _accentBlue = Color(0xFF1E8BC3);
const Color _logoGreen = Color(0xFF52BE80);

class FindCaregiverScreen extends StatefulWidget {
  const FindCaregiverScreen({super.key});

  @override
  State<FindCaregiverScreen> createState() => _FindCaregiverScreenState();
}

class _FindCaregiverScreenState extends State<FindCaregiverScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FindCaregiverViewModel>(
      builder: (context, viewModel, child) {
        final state = viewModel.uiState;
        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          appBar: _buildGlassAppBar(context),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0D3B66),
                  Color(0xFF1A5276),
                  Color(0xFF1E8BC3),
                  Color(0xFF52BE80),
                ],
                stops: [0.0, 0.35, 0.65, 1.0],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Glass search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GlassContainer(
                      borderRadius: 28,
                      blur: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: Colors.white.withOpacity(0.8)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: viewModel.updateSearchQuery,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: "Search by name or location...",
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Glass category pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: ["All", "Caregiver", "Nurse"].map((category) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GlassPill(
                            label: category,
                            selected: viewModel.selectedCategory == category,
                            onTap: () => viewModel.updateCategory(category),
                            accentColor: _accentBlue,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // List
                  Expanded(
                    child: state.isLoading
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : state.errorMessage != null
                            ? Center(child: Text(state.errorMessage!, style: const TextStyle(color: Colors.white70)))
                            : state.caregivers.isEmpty
                                ? const Center(child: Text("No caregivers found.", style: TextStyle(color: Colors.white70)))
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    itemCount: state.caregivers.length,
                                    itemBuilder: (context, index) {
                                      final caregiver = state.caregivers[index];
                                      final isFav = viewModel.favoriteCaregiverIds.contains(caregiver.id);
                                      return _buildGlassCard(context, caregiver, isFav, viewModel);
                                    },
                                  ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildGlassAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AppBar(
            backgroundColor: Colors.white.withOpacity(0.12),
            elevation: 0,
            title: const Text(
              'Find Caregiver or Nurse',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 0.5, color: Colors.white.withOpacity(0.25)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard(BuildContext context, User caregiver, bool isFav, FindCaregiverViewModel viewModel) {
    ImageProvider? imageProvider;
    if (caregiver.profileImageUrl.isNotEmpty) {
      try {
        imageProvider = MemoryImage(base64Decode(caregiver.profileImageUrl.split(',').last));
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        borderRadius: 18,
        blur: 20,
        child: InkWell(
          onTap: () => _showCaregiverDetails(context, caregiver, viewModel),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.25),
                    border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                    image: imageProvider != null
                        ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                        : null,
                  ),
                  child: imageProvider == null
                      ? Center(
                          child: Text(
                            caregiver.name.isNotEmpty ? caregiver.name[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caregiver.name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${caregiver.role} • ${caregiver.experienceYears} yrs exp",
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7)),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 15),
                          const SizedBox(width: 3),
                          Text(
                            "${caregiver.rating.toStringAsFixed(1)} (${caregiver.reviewCount})",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Favourite
                GestureDetector(
                  onTap: () => viewModel.toggleFavorite(caregiver.id),
                  child: Icon(
                    isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isFav ? Colors.redAccent : Colors.white.withOpacity(0.6),
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCaregiverDetails(BuildContext context, User caregiver, FindCaregiverViewModel viewModel) {
    viewModel.fetchReviewsForCaregiver(caregiver.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.22),
                    Colors.white.withOpacity(0.08),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.35), width: 1.2)),
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.8,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                expand: false,
                builder: (_, scrollController) {
                  return Consumer<FindCaregiverViewModel>(
                    builder: (context, vm, _) {
                      ImageProvider? img;
                      if (caregiver.profileImageUrl.isNotEmpty) {
                        try { img = MemoryImage(base64Decode(caregiver.profileImageUrl.split(',').last)); } catch (_) {}
                      }
                      return SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Container(
                              width: 40, height: 4,
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.white.withOpacity(0.25),
                              backgroundImage: img,
                              child: img == null
                                  ? Text(caregiver.name[0].toUpperCase(), style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold))
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            Text(caregiver.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text(caregiver.role, style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7))),
                            const SizedBox(height: 20),
                            // Book button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _logoGreen.withOpacity(0.85),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: () {
                                  context.pop();
                                  context.push('/create_job', extra: {'caregiverId': caregiver.id, 'caregiverName': caregiver.name});
                                },
                                child: const Text("Book this Caregiver / Nurse", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text("Client Reviews", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white.withOpacity(0.9))),
                            ),
                            const SizedBox(height: 8),
                            if (vm.isReviewsLoading)
                              const CircularProgressIndicator(color: Colors.white)
                            else if (vm.reviewsState.isEmpty)
                              Text("No reviews yet.", style: TextStyle(color: Colors.white.withOpacity(0.6)))
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: vm.reviewsState.length,
                                itemBuilder: (context, i) {
                                  final review = vm.reviewsState[i];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: GlassContainer(
                                      borderRadius: 14,
                                      blur: 16,
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: List.generate(5, (j) => Icon(
                                              Icons.star_rounded, size: 16,
                                              color: j < review.rating ? Colors.amber : Colors.white.withOpacity(0.25),
                                            )),
                                          ),
                                          if (review.comment.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(review.comment, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    ).whenComplete(() => viewModel.clearReviews());
  }
}
