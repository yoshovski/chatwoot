import {
  setAuthCredentials,
  throwErrorMessage,
  clearLocalStorageOnLogout,
  parseAPIErrorResponse,
} from 'dashboard/store/utils/api';
import wootAPI from './apiClient';
import {
  getLoginRedirectURL,
  getCredentialsFromEmail,
} from '../helpers/AuthHelper';

export const login = async ({
  ssoAccountId,
  ssoConversationId,
  ...credentials
}) => {
  try {
    const response = await wootAPI.post('auth/sign_in', credentials);

    // Check if MFA is required
    if (response.status === 206 && response.data.mfa_required) {
      // Return MFA data instead of throwing error
      return {
        mfaRequired: true,
        mfaToken: response.data.mfa_token,
      };
    }

    setAuthCredentials(response);
    clearLocalStorageOnLogout();
    window.location = getLoginRedirectURL({
      ssoAccountId,
      ssoConversationId,
      user: response.data.data,
    });
    return null;
  } catch (error) {
    // Check if it's an MFA required response
    if (error.response?.status === 206 && error.response?.data?.mfa_required) {
      return {
        mfaRequired: true,
        mfaToken: error.response.data.mfa_token,
      };
    }
    if (
      error.response?.status === 409 &&
      error.response?.data?.sessions_limit_reached
    ) {
      return {
        sessionsLimitReached: true,
        sessions: error.response.data.sessions,
      };
    }
    const loginError = new Error(parseAPIErrorResponse(error));
    loginError.errorCode = error.response?.data?.error_code;
    throw loginError;
  }
};

export const register = async creds => {
  try {
    const { fullName, accountName } = getCredentialsFromEmail(creds.email);
    const response = await wootAPI.post('api/v1/accounts.json', {
      account_name: accountName,
      user_full_name: fullName,
      email: creds.email,
      password: creds.password,
      captcha_response: creds.captchaResponse,
      website: creds.website,
      // The form shows the line agreeing to the terms and the privacy policy next to the button.
      terms_accepted: true,
    });
    return response.data;
  } catch (error) {
    // `code` (email_taken, email_blocked, …) lets the form show the error under the email field.
    const signupError = new Error(parseAPIErrorResponse(error));
    signupError.code = error.response?.data?.code;
    throw signupError;
  }
};

export const resendConfirmation = async ({ email, captchaResponse }) => {
  return wootAPI.post('resend_confirmation', {
    email,
    captcha_response: captchaResponse,
  });
};

export const verifyPasswordToken = async ({ confirmationToken }) => {
  try {
    const response = await wootAPI.post('auth/confirmation', {
      confirmation_token: confirmationToken,
    });
    setAuthCredentials(response);
  } catch (error) {
    throwErrorMessage(error);
  }
};

export const setNewPassword = async ({
  resetPasswordToken,
  password,
  confirmPassword,
}) => {
  try {
    const response = await wootAPI.put('auth/password', {
      reset_password_token: resetPasswordToken,
      password_confirmation: confirmPassword,
      password,
    });
    setAuthCredentials(response);
  } catch (error) {
    throwErrorMessage(error);
  }
};

export const resetPassword = async ({ email }) =>
  wootAPI.post('auth/password', { email });
