import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/driver_data.dart';
import '../../core/services.dart';
import '../auth/driver_auth.dart';

const _accent = MigaColors.driverAccent;

/// Pick a new work city. The server refuses while deliveries are in progress (shown as an error).
Future<void> changeWorkCity(BuildContext context) async {
  final List<City> cities;
  try {
    cities = [for (final r in await AppServices.api.catalog.regions()) ...r.cities];
  } catch (e) {
    if (context.mounted) showMigaError(context, e);
    return;
  }
  if (!context.mounted) return;
  final current = DriverData.instance.home?.cityName;
  final picked = await showMigaPicker<City>(
    context: context,
    title: 'مدينة العمل',
    items: cities,
    label: (c) => c.nameAr,
    selected: cities.where((c) => c.nameAr == current).firstOrNull,
    icon: Icons.location_city_rounded,
    accent: _accent,
  );
  if (picked == null || picked.nameAr == current || !context.mounted) return;
  try {
    await AppServices.api.driver.updateProfile(cityId: picked.id);
    await DriverData.instance.refresh();
    if (context.mounted) showMigaMessage(context, 'مدينة عملك الآن ${picked.nameAr} — ستصلك طلباتها');
  } catch (e) {
    if (context.mounted) showMigaError(context, e);
  }
}

/// Edit vehicle type, model and plate number.
Future<void> editVehicle(BuildContext context) async {
  final home = DriverData.instance.home;
  var type = home?.vehicleType ?? 'van';
  final model = TextEditingController(text: home?.vehicleModel);
  final plate = TextEditingController(text: home?.plateNumber);
  var saving = false;
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder:
        (c) => StatefulBuilder(
          builder:
              (c, set) => Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(c).bottom + 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('بيانات المركبة', style: Theme.of(c).textTheme.titleLarge),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (value, label, icon) in vehicleOptions)
                          MigaChoiceChip(label: label, icon: icon, selected: type == value, onSelected: () => set(() => type = value)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    MigaTextField(
                      label: 'موديل المركبة',
                      hint: 'مثال: تويوتا هايس 2022',
                      controller: model,
                      prefixIcon: Icons.directions_car_outlined,
                    ),
                    const SizedBox(height: 12),
                    MigaTextField(label: 'رقم اللوحة', hint: 'مثال: أ ب ج 1234', controller: plate, prefixIcon: Icons.pin_outlined),
                    const SizedBox(height: 16),
                    MigaButton(
                      label: 'حفظ',
                      loading: saving,
                      onPressed: () async {
                        if (plate.text.trim().length < 3) {
                          showMigaError(c, const ApiException(400, 'validation_error', 'أدخل رقم اللوحة'));
                          return;
                        }
                        set(() => saving = true);
                        try {
                          await AppServices.api.driver.updateProfile(
                            vehicleType: type,
                            vehicleModel: model.text.trim(),
                            plateNumber: plate.text.trim(),
                          );
                          await DriverData.instance.refresh();
                          if (c.mounted) Navigator.pop(c, true);
                        } catch (e) {
                          if (c.mounted) {
                            set(() => saving = false);
                            showMigaError(c, e);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
        ),
  );
  if (saved == true && context.mounted) showMigaMessage(context, 'تم حفظ بيانات المركبة');
}
