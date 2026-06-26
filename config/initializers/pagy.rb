require "pagy"

# Pagy 43: configure via the mutable Pagy::OPTIONS hash (Pagy::DEFAULT is frozen).
# Out-of-range pages return an empty page by default, so no overflow extra is needed.
Pagy::OPTIONS[:limit] = 20
Pagy::OPTIONS[:slots] = 7
