// A web build deliberately has no references to the native route-key define
// names. The one referrer-restricted browser key serves Maps JavaScript and
// Routes, and is necessarily visible in the downloaded JavaScript bundle.
const configuredMapsApiKey = String.fromEnvironment('MAPS_API_KEY');
const configuredAndroidRoutesKey = '';
const configuredIosRoutesKey = '';
const configuredWebRoutesKey = configuredMapsApiKey;
