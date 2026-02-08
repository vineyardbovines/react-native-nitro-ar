const { withInfoPlist, withEntitlementsPlist, withXcodeProject } = require('@expo/config-plugins');

const withNitroAR = (config) => {
  // Add camera usage description
  config = withInfoPlist(config, (config) => {
    config.modResults.NSCameraUsageDescription =
      config.modResults.NSCameraUsageDescription ||
      'This app uses the camera for augmented reality features.';

    // Add ARKit to required device capabilities
    if (!config.modResults.UIRequiredDeviceCapabilities) {
      config.modResults.UIRequiredDeviceCapabilities = [];
    }
    if (!config.modResults.UIRequiredDeviceCapabilities.includes('arkit')) {
      config.modResults.UIRequiredDeviceCapabilities.push('arkit');
    }

    return config;
  });

  return config;
};

module.exports = withNitroAR;
