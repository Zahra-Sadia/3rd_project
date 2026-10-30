import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: AppColors.surface,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

void showCurrencyDialog(
  BuildContext context,
  String currentCurrency,
  ValueChanged<String> onSelected,
) {
  const currencies = [
    'BDT (৳)',
    'USD (\$)',
    'EUR (€)',
    'GBP (£)',
    'INR (₹)',
    'AUD (A\$)',
    'CAD (C\$)',
  ];

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Choose Currency',
        style: TextStyle(color: AppColors.primaryText),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: currencies.map((currency) {
          return RadioListTile<String>(
            value: currency,
            groupValue: currentCurrency,
            activeColor: AppColors.roseGold,
            title: Text(
              currency,
              style: const TextStyle(color: AppColors.primaryText),
            ),
            onChanged: (value) {
              if (value != null) {
                onSelected(value);
                Navigator.pop(dialogContext);
              }
            },
          );
        }).toList(),
      ),
    ),
  );
}

void showFontDialog(
  BuildContext context,
  String currentFont,
  ValueChanged<String> onSelected,
) {
  const fonts = ['Inter', 'Roboto', 'Poppins', 'Lato', 'Open Sans'];

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Choose Font',
        style: TextStyle(color: AppColors.primaryText),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: fonts.map((font) {
          return RadioListTile<String>(
            value: font,
            groupValue: currentFont,
            activeColor: AppColors.roseGold,
            title: Text(
              font,
              style: const TextStyle(color: AppColors.primaryText),
            ),
            onChanged: (value) {
              if (value != null) {
                onSelected(value);
                Navigator.pop(dialogContext);
              }
            },
          );
        }).toList(),
      ),
    ),
  );
}

void showLanguageDialog(
  BuildContext context,
  String currentLanguage,
  ValueChanged<String> onSelected,
) {
  const languages = ['English', 'বাংলা'];

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Choose Language',
        style: TextStyle(color: AppColors.primaryText),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: languages.map((language) {
          return RadioListTile<String>(
            value: language,
            groupValue: currentLanguage,
            activeColor: AppColors.roseGold,
            title: Text(
              language,
              style: const TextStyle(color: AppColors.primaryText),
            ),
            onChanged: (value) {
              if (value != null) {
                onSelected(value);
                Navigator.pop(dialogContext);
              }
            },
          );
        }).toList(),
      ),
    ),
  );
}

void showChangePinDialog(BuildContext context) {
  final formKey = GlobalKey<FormState>();
  final oldPinController = TextEditingController();
  final newPinController = TextEditingController();
  final confirmPinController = TextEditingController();

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Change PIN',
        style: TextStyle(color: AppColors.primaryText),
      ),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _pinField(oldPinController, 'Current PIN'),
              const SizedBox(height: 12),
              _pinField(newPinController, 'New PIN'),
              const SizedBox(height: 12),
              _pinField(confirmPinController, 'Confirm New PIN'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              if (newPinController.text != confirmPinController.text) {
                showMessage(context, 'New PINs do not match.');
                return;
              }

              Navigator.pop(dialogContext);
              showMessage(
                context,
                'PIN change UI completed, but PIN storage is not connected.',
              );
            }
          },
          child: const Text(
            'Update PIN',
            style: TextStyle(color: AppColors.roseGold),
          ),
        ),
      ],
    ),
  ).then((_) {
    oldPinController.dispose();
    newPinController.dispose();
    confirmPinController.dispose();
  });
}

Widget _pinField(TextEditingController controller, String label) {
  return TextFormField(
    controller: controller,
    obscureText: true,
    keyboardType: TextInputType.number,
    maxLength: 6,
    style: const TextStyle(color: AppColors.primaryText),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.secondaryText),
      counterText: '',
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.secondaryText),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.roseGold),
      ),
    ),
    validator: (value) {
      if (value == null || value.length < 4) {
        return 'Enter at least 4 digits';
      }
      if (!RegExp(r'^\d+$').hasMatch(value)) {
        return 'PIN must contain digits only';
      }
      return null;
    },
  );
}

void showExportDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Export My Data',
        style: TextStyle(color: AppColors.primaryText),
      ),
      content: const Text(
        'Choose an export format. Actual file export still needs to be implemented.',
        style: TextStyle(color: AppColors.secondaryText),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            showMessage(context, 'CSV export is not implemented yet.');
          },
          child: const Text('CSV'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            showMessage(context, 'PDF export is not implemented yet.');
          },
          child: const Text('PDF'),
        ),
      ],
    ),
  );
}

void showDeleteAccountDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Delete Account?',
        style: TextStyle(color: AppColors.primaryText),
      ),
      content: const Text(
        'This action is permanent. Account deletion is not connected yet.',
        style: TextStyle(color: AppColors.secondaryText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            showMessage(context, 'Account deletion has not been implemented.');
          },
          child: const Text('OK', style: TextStyle(color: AppColors.roseGold)),
        ),
      ],
    ),
  );
}

void showAutoLockDialog(
  BuildContext context,
  String currentDuration,
  ValueChanged<String> onSelected,
) {
  const durations = ['Immediately', '1 minute', '5 minutes', '10 minutes'];

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Auto Lock Duration',
        style: TextStyle(color: AppColors.primaryText),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: durations.map((duration) {
          return RadioListTile<String>(
            value: duration,
            groupValue: currentDuration,
            activeColor: AppColors.roseGold,
            title: Text(
              duration,
              style: const TextStyle(color: AppColors.primaryText),
            ),
            onChanged: (value) {
              if (value != null) {
                onSelected(value);
                Navigator.pop(dialogContext);
              }
            },
          );
        }).toList(),
      ),
    ),
  );
}

void showPrivacyDialog(BuildContext context) {
  showMessage(context, 'Privacy settings are not connected yet.');
}
