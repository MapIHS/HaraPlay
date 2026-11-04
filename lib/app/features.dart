import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The equalizer and loudness boost. Off since 0.1.1: on some devices
/// (seen on a vivo iQOO Z9x) switching them caused volume bursts.
///
/// While off, no audio effect is created, probed or attached to either
/// player, the Equalizer row is hidden, and saved or restored equalizer
/// settings are kept but not used. The code stays as it was in 0.1.0.
const bool kEqualizerEnabled = false;

/// [kEqualizerEnabled] for the UI; tests of the (disabled) equalizer
/// screens override it.
final equalizerEnabledProvider = Provider<bool>((ref) => kEqualizerEnabled);
