import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_localizations.dart';
import '../utils/responsive_helper.dart';
import '../widgets/app_background.dart';
import '../providers/language_provider.dart';
import 'package:provider/provider.dart';

class DonationScreen extends StatefulWidget {
  const DonationScreen({super.key});

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen> {
  final Map<String, String> _wallets = {
    'Ethereum (ETH)': '0xae963BF541F90Dd687419C8c442c7d6b85F60d55',
    'Tether (USDT-TRC20)': 'TXd74xCtRAvpZaHsxEYF4WdoHQBLQwo3ob',
    'Tether (USDT-BEP20)': '0xae963BF541F90Dd687419C8c442c7d6b85F60d55',
    'Tron (TRX)': 'TXd74xCtRAvpZaHsxEYF4WdoHQBLQwo3ob',
    'Toncoin (TON)': 'UQBRCtsfiqEVVdjO9lejWdcq1OumwL2dvht2P0G7aTlXo8mQ',
  };

  Future<void> _copyToClipboard(String text, String cryptoName) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)
                .translate('donation.address_copied')
                .replaceAll('{crypto}', cryptoName),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.white.withValues(alpha: 0.10),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          elevation: 0,
          margin: const EdgeInsets.all(20),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Directionality(
          textDirection: languageProvider.textDirection,
          child: AppBackground(
            useSecondaryBackground: true,
            child: SafeArea(
              child: ResponsivePageWrapper(
                child: Column(
                  children: [
                    _buildHeader(context, responsive, languageProvider),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.horizontalPadding,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: responsive.scale(24)),
                            _buildHero(responsive),
                            SizedBox(height: responsive.scale(28)),
                            ..._wallets.entries.map((entry) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: responsive.scale(12),
                                ),
                                child: _buildWalletCard(
                                  cryptoName: entry.key,
                                  address: entry.value,
                                  responsive: responsive,
                                ),
                              );
                            }),
                            SizedBox(height: responsive.scale(16)),
                            _buildThankYouCard(responsive),
                            const SizedBox(height: 32),
                          ],
                        ),
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
  }

  Widget _buildHeader(
    BuildContext context,
    ResponsiveHelper responsive,
    LanguageProvider languageProvider,
  ) {
    return Padding(
      padding: EdgeInsets.all(responsive.horizontalPadding),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(responsive.scale(11)),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 1,
                ),
              ),
              child: Icon(
                languageProvider.isRtl
                    ? Icons.arrow_forward_rounded
                    : Icons.arrow_back_rounded,
                color: Colors.white,
                size: responsive.scale(20),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              AppLocalizations.of(context).translate('donation.header'),
              style: GoogleFonts.poppins(
                fontSize: responsive.scale(18).clamp(16.0, 22.0),
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(ResponsiveHelper responsive) {
    return Column(
      children: [
        Container(
          width: responsive.scale(72),
          height: responsive.scale(72),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.favorite_rounded,
            color: Colors.white.withValues(alpha: 0.9),
            size: responsive.scale(30),
          ),
        ),
        SizedBox(height: responsive.scale(18)),
        Text(
          AppLocalizations.of(context).translate('donation.title'),
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: responsive.scale(22).clamp(20.0, 26.0),
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: -0.4,
            height: 1.2,
          ),
        ),
        SizedBox(height: responsive.scale(8)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: responsive.scale(12)),
          child: Text(
            AppLocalizations.of(context).translate('donation.description'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: responsive.scale(13).clamp(12.0, 15.0),
              height: 1.6,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWalletCard({
    required String cryptoName,
    required String address,
    required ResponsiveHelper responsive,
  }) {
    final shortName = cryptoName.split(' ').first;
    final tag = cryptoName.contains('(')
        ? cryptoName.substring(cryptoName.indexOf('(') + 1).replaceAll(')', '')
        : '';

    return Container(
      padding: EdgeInsets.all(responsive.scale(16)),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(responsive.scale(9)),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Icon(
                  _getCryptoIcon(cryptoName),
                  color: Colors.white.withValues(alpha: 0.85),
                  size: responsive.scale(18),
                ),
              ),
              SizedBox(width: responsive.scale(12)),
              Expanded(
                child: Text(
                  shortName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: responsive.scale(15).clamp(13.0, 17.0),
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              if (tag.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.scale(9),
                    vertical: responsive.scale(4),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: responsive.scale(10).clamp(9.0, 12.0),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: responsive.scale(14)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.scale(12),
              vertical: responsive.scale(10),
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    address,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: responsive.scale(11).clamp(10.0, 13.0),
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: responsive.scale(8)),
                GestureDetector(
                  onTap: () => _copyToClipboard(address, cryptoName),
                  child: Container(
                    padding: EdgeInsets.all(responsive.scale(8)),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.copy_rounded,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: responsive.scale(15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThankYouCard(ResponsiveHelper responsive) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.scale(8),
        vertical: responsive.scale(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_rounded,
            color: const Color(0xFFFF3B5C),
            size: responsive.scale(18),
          ),
          SizedBox(width: responsive.scale(10)),
          Flexible(
            child: Text(
              AppLocalizations.of(context).translate('donation.thank_you'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: responsive.scale(13).clamp(11.0, 15.0),
                fontWeight: FontWeight.w500,
                height: 1.5,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCryptoIcon(String cryptoName) {
    if (cryptoName.contains('Ethereum')) return Icons.diamond_outlined;
    if (cryptoName.contains('Tether')) return Icons.attach_money_rounded;
    if (cryptoName.contains('Tron')) return Icons.flash_on_rounded;
    if (cryptoName.contains('Toncoin')) return Icons.currency_exchange_rounded;
    return Icons.currency_exchange_rounded;
  }
}
