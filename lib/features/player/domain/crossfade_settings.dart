/// Crossfade settings: [length] zero means off (the default), and the
/// player then never touches its second player at all. [onSkip] also fades
/// on manual skips to the next song.
typedef CrossfadeSettings = ({Duration length, bool onSkip});

const crossfadeOff = (length: Duration.zero, onSkip: false);
