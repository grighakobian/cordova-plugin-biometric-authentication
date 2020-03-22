var exec = require('cordova/exec');

exports.analyze = function (arg0, success, error) {
    exec(success, error, 'BiometricAuthentication', 'coolMethod', [arg0]);
};
