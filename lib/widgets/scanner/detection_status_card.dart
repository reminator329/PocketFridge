import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Carte inférieure affichant l'état de détection du nom et de la date en direct.
class DetectionStatusCard extends StatelessWidget {
  final String? productName;
  final bool isSearchingName;
  final DateTime? expirationDate;
  final VoidCallback onConfirm;
  final VoidCallback onManualEntry;

  const DetectionStatusCard({
    super.key,
    required this.productName,
    required this.isSearchingName,
    required this.expirationDate,
    required this.onConfirm,
    required this.onManualEntry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasName = productName != null && productName!.isNotEmpty;
    final hasDate = expirationDate != null;
    final isComplete = hasName && hasDate;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isComplete
              ? Colors.greenAccent.shade400
              : theme.colorScheme.outline.withValues(alpha: 0.2),
          width: isComplete ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Titre / Instructions
          Row(
            children: [
              Icon(
                isComplete
                    ? Icons.check_circle_rounded
                    : Icons.qr_code_scanner_rounded,
                color: isComplete ? Colors.green : theme.colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isComplete
                      ? "Informations détectées !"
                      : "Pointez vers le code-barres et la date",
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Ligne 1 : Nom du produit
          _StatusRow(
            icon: Icons.fastfood_rounded,
            label: "Article",
            value: isSearchingName
                ? "Recherche du produit..."
                : (hasName ? productName! : "Non trouvé (Scannez le code-barres)"),
            isSuccess: hasName,
            isLoading: isSearchingName,
          ),
          const SizedBox(height: 10),

          // Ligne 2 : Date d'expiration
          _StatusRow(
            icon: Icons.calendar_today_rounded,
            label: "Date",
            value: hasDate
                ? DateFormat('dd/MM/yyyy').format(expirationDate!)
                : "Non trouvée (Viser la date DLC)",
            isSuccess: hasDate,
            isLoading: false,
          ),
          const SizedBox(height: 16),

          // Boutons d'action
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onManualEntry,
                  child: const Text("Saisie manuelle"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isComplete
                        ? Colors.green.shade600
                        : theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: (hasName || hasDate) ? onConfirm : null,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(
                    isComplete ? "Valider" : "Continuer",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isSuccess;
  final bool isLoading;

  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isSuccess,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color statusColor;
    if (isLoading) {
      statusColor = Colors.orange;
    } else if (isSuccess) {
      statusColor = Colors.green;
    } else {
      statusColor = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSuccess
            ? Colors.green.withValues(alpha: 0.08)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSuccess
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: statusColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSuccess ? FontWeight.bold : FontWeight.normal,
                    color: isSuccess
                        ? (theme.brightness == Brightness.dark
                            ? Colors.greenAccent
                            : Colors.green.shade800)
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (isSuccess)
            const Icon(Icons.check_circle, size: 18, color: Colors.green)
          else
            Icon(
              Icons.radio_button_unchecked,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
        ],
      ),
    );
  }
}
