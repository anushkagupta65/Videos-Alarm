# Keep rules to suppress missing class warnings for proguard.annotation.Keep and KeepClassMembers

# Don't warn about missing annotation classes
-dontwarn proguard.annotation.Keep
-dontwarn proguard.annotation.KeepClassMembers

# Optionally, keep references if they ever exist
-keep class proguard.annotation.Keep { *; }
-keep class proguard.annotation.KeepClassMembers { *; }

-keep class com.razorpay.** { *; }