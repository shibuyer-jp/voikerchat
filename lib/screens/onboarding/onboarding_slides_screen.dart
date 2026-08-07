import 'package:flutter/material.dart';
import 'package:voikerchat/l10n/app_localizations.dart';
import '../../services/learner_preferences_service.dart';
import '../../theme/app_colors.dart';

/// OnboardingSlidesScreen: 診断テスト前の説明スライド3枚(施策③)。
///
/// 画像(assets/onboarding/)自体にキャプションが焼き込まれているため、
/// スライド上に追加のテキストラベルは置かない。端末ロケール(ja/en/fil)に
/// 応じて画像を切り替え、対応外のロケールは en にフォールバックする
/// (MaterialApp側のロケール解決で既にenへフォールバックされるはずだが、
/// 万一に備えて念のため二重にフォールバックする)。
class OnboardingSlidesScreen extends StatefulWidget {
  /// スキップ/最終スライド完了のいずれでも呼ばれる(次の画面へ進む)。
  final VoidCallback onDone;

  const OnboardingSlidesScreen({super.key, required this.onDone});

  @override
  State<OnboardingSlidesScreen> createState() =>
      _OnboardingSlidesScreenState();
}

class _OnboardingSlidesScreenState extends State<OnboardingSlidesScreen> {
  static const int _slideCount = 3;
  static const Set<String> _supportedImageLocales = {'ja', 'en', 'fil'};

  final _learnerPreferencesService = LearnerPreferencesService();
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _completing = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _imageLocaleCode(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return _supportedImageLocales.contains(code) ? code : 'en';
  }

  Future<void> _complete() async {
    if (_completing) return;
    _completing = true;
    await _learnerPreferencesService.setOnboardingSlidesCompleted(true);
    widget.onDone();
  }

  void _handleNext() {
    if (_currentPage < _slideCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final localeCode = _imageLocaleCode(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _slideCount,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) {
                final slideNumber = index + 1;
                final isLastPage = index == _slideCount - 1;
                return Center(
                  child: AspectRatio(
                    aspectRatio: 1536 / 2752,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            'assets/onboarding/slide${slideNumber}_$localeCode.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        Positioned(
                          left: 24,
                          right: 24,
                          bottom: 24,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(_slideCount, (dotIndex) {
                                  final active = dotIndex == _currentPage;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin:
                                        const EdgeInsets.symmetric(horizontal: 4),
                                    width: active ? 20 : 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: active
                                          ? AppColors.brand
                                          : Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _handleNext,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.brand,
                                    foregroundColor: Colors.white,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    isLastPage
                                        ? l.onboardingSlidesStart
                                        : l.onboardingSlidesNext,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: TextButton(
                onPressed: _complete,
                child: Text(
                  l.onboardingSlidesSkip,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
