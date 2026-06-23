import 'package:flutter/material.dart';

/// OnboardingProgressBar: Onboarding フロー全体のプログレスバー
/// 
/// Step 1-5 の進捗を視覚化する。
/// - 上部に横方向プログレスバー
/// - 現在ステップをテキスト表示
/// - スムーズなアニメーション付き
class OnboardingProgressBar extends StatefulWidget {
  /// 現在のステップ（1-5, 0はオンボーディング前）
  final int currentStep;

  /// ステップ完了状態（各ステップが完了したか）
  final List<bool> completedSteps;

  /// プログレスバー高さ
  final double height;

  /// カラースキーム（デフォルト: Voikerchat ブルー）
  final Color activeColor;
  final Color inactiveColor;

  const OnboardingProgressBar({
    Key? key,
    required this.currentStep,
    this.completedSteps = const [false, false, false, false, false],
    this.height = 8.0,
    this.activeColor = const Color(0xFF0099FF),
    this.inactiveColor = const Color(0xFFE0E0E0),
  }) : super(key: key);

  @override
  State<OnboardingProgressBar> createState() => _OnboardingProgressBarState();
}

class _OnboardingProgressBarState extends State<OnboardingProgressBar>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0,
      end: _calculateProgress(),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void didUpdateWidget(OnboardingProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStep != widget.currentStep ||
        oldWidget.completedSteps != widget.completedSteps) {
      _animationController.reset();
      _setupAnimation();
    }
  }

  double _calculateProgress() {
    if (widget.currentStep == 0) return 0;
    return (widget.currentStep - 1) / 5;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // テキスト表示: "ステップ 2/5"
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ステップ ${widget.currentStep}/5',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0099FF),
                    ),
              ),
              _buildStepIndicators(),
            ],
          ),
        ),
        // プログレスバー本体
        ClipRRect(
          borderRadius: BorderRadius.circular(widget.height / 2),
          child: LinearProgressIndicator(
            minHeight: widget.height,
            value: _progressAnimation.value,
            backgroundColor: widget.inactiveColor,
            valueColor: AlwaysStoppedAnimation<Color>(widget.activeColor),
          ),
        ),
      ],
    );
  }

  /// ステップ完了インジケーター（小さなドット）
  Widget _buildStepIndicators() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final isCompleted = widget.completedSteps.length > index &&
            widget.completedSteps[index];
        final isCurrent = widget.currentStep == index + 1;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: _buildStepDot(
            isCompleted: isCompleted,
            isCurrent: isCurrent,
          ),
        );
      }),
    );
  }

  /// 個別のステップドット
  Widget _buildStepDot({
    required bool isCompleted,
    required bool isCurrent,
  }) {
    Color dotColor;
    if (isCompleted) {
      dotColor = const Color(0xFF00CC00); // グリーン: 完了
    } else if (isCurrent) {
      dotColor = const Color(0xFF0099FF); // ブルー: 現在
    } else {
      dotColor = const Color(0xFFCCCCCC); // グレー: 未完了
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isCurrent ? 12 : 8,
      height: isCurrent ? 12 : 8,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: dotColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: isCompleted
          ? const Center(
              child: Icon(
                Icons.check,
                size: 6,
                color: Colors.white,
              ),
            )
          : null,
    );
  }
}
