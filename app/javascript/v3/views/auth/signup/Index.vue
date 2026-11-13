<script setup>
import AuthLayout from '../../../components/AuthLayout/AuthLayout.vue';
import SignupForm from './components/Signup/Form.vue';
import PlanTrial from './components/PlanTrial.vue';
</script>

<template>
  <AuthLayout
    :title="$t('REGISTER.TITLE')"
    :description="$t('REGISTER.DESCRIPTION')"
    :panel-title="$t('REGISTER.PANEL.TITLE')"
    :panel-description="$t('REGISTER.PANEL.DESCRIPTION')"
  >
    <template #beforeTitle>
      <PlanTrial />
    </template>
    <SignupForm />
    <p class="mt-6 mb-0 text-sm text-n-slate-11">
      {{ $t('REGISTER.HAVE_AN_ACCOUNT') }}
      <router-link to="/app/login" class="text-link">
        {{ $t('REGISTER.LOG_IN') }}
      </router-link>
    </p>
  </AuthLayout>
</template>
