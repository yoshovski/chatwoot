<script>
import { DEFAULT_REDIRECT_URL } from 'dashboard/constants/globals';
import { verifyPasswordToken } from '../../../api/auth';
import Spinner from 'shared/components/Spinner.vue';
import AuthLayout from '../../../components/AuthLayout/AuthLayout.vue';

export default {
  components: { Spinner, AuthLayout },
  props: {
    confirmationToken: {
      type: String,
      default: '',
    },
  },
  mounted() {
    this.confirmToken();
  },
  methods: {
    async confirmToken() {
      try {
        await verifyPasswordToken({
          confirmationToken: this.confirmationToken,
        });
        window.location = DEFAULT_REDIRECT_URL;
      } catch (error) {
        window.location = DEFAULT_REDIRECT_URL;
      }
    },
  },
};
</script>

<template>
  <AuthLayout>
    <div class="flex items-center gap-2 text-n-slate-11">
      <Spinner color-scheme="primary" size="" />
      {{ $t('CONFIRM_EMAIL') }}
    </div>
  </AuthLayout>
</template>
