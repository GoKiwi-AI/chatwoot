# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Devise::Mailer' do
  describe 'confirmation_instructions with Enterprise features' do
    let(:account) { create(:account) }
    let!(:confirmable_user) { create(:user, inviter: inviter_val, account: account) }
    let(:inviter_val) { nil }
    let(:mail) { Devise::Mailer.confirmation_instructions(confirmable_user.reload, nil, {}) }
    let(:mail_body) { CGI.unescapeHTML(mail.body.to_s) }

    before do
      confirmable_user.update!(confirmed_at: nil)
      confirmable_user.send(:generate_confirmation_token)
    end

    context 'when brand name is intentionally blank' do
      before do
        create(:installation_config, name: 'BRAND_NAME', value: '')
      end

      it 'preserves the blank brand override' do
        expect(mail_body).not_to include('Chatwoot')
      end
    end

    context 'with SAML enabled account' do
      let(:saml_settings) { create(:account_saml_settings, account: account) }

      before { saml_settings }

      context 'when user has no inviter' do
        it 'shows standard welcome message without SSO references' do
          expect(mail_body).to include('Conferma la tua email per iniziare')
          expect(mail_body).to include('Dobbiamo solo verificare il tuo indirizzo email prima che tu possa iniziare a usare il tuo account.')
          expect(mail_body).not_to include('Single Sign-On (SSO)')
        end

        it 'shows the standard confirmation CTA' do
          expect(mail_body).to include('Conferma il mio account')
        end

        it 'shows confirmation link' do
          expect(mail.body).to include("app/auth/confirmation?confirmation_token=#{confirmable_user.confirmation_token}")
        end
      end

      context 'when user has inviter and SAML is enabled' do
        let(:inviter_val) { create(:user, :administrator, skip_confirmation: true, account: account) }

        it 'mentions SSO invitation' do
          expect(mail_body).to include("Sei stato invitato a unirti a #{account.name}")
          expect(mail_body).to include("#{inviter_val.name} ti ha invitato ad accedere allo spazio di lavoro #{account.name} su Chatwoot.")
        end

        it 'explains SSO authentication' do
          expect(mail_body).to include('La tua organizzazione usa Single Sign-On (SSO), quindi non dovrai creare una password separata.')
        end

        it 'does not show standard invitation message' do
          expect(mail_body).not_to include('ti ha invitato a unirti')
          expect(mail_body).not_to include('Accetta invito')
        end

        it 'directs to SSO portal instead of password reset' do
          expect(mail_body).to include('Usa il portale SSO della tua organizzazione')
          expect(mail.body).not_to include('app/auth/password/edit')
        end
      end

      context 'when user is already confirmed and has inviter' do
        let(:inviter_val) { create(:user, :administrator, skip_confirmation: true, account: account) }

        before do
          confirmable_user.confirm
        end

        it 'shows SSO login instructions' do
          expect(mail_body).to include('Il tuo accesso e pronto')
          expect(mail_body).to include("Accedi con l'SSO della tua organizzazione")
          expect(mail_body).to include('Usa il portale Single Sign-On (SSO) della tua organizzazione per accedere')
          expect(mail.body).not_to include('/auth/sign_in')
        end
      end

      context 'when user updates email on SAML account' do
        let(:inviter_val) { create(:user, :administrator, skip_confirmation: true, account: account) }

        before do
          confirmable_user.update!(email: 'updated@example.com')
        end

        it 'still shows confirmation link for email verification' do
          expect(mail_body).to include('Conferma il tuo nuovo indirizzo email')
          expect(mail.body).to include('app/auth/confirmation?confirmation_token')
          expect(confirmable_user.unconfirmed_email.blank?).to be false
        end
      end

      context 'when user is already confirmed with no inviter' do
        before do
          confirmable_user.confirm
        end

        it 'shows SSO login instructions instead of regular login' do
          expect(mail_body).to include('Il tuo accesso e pronto')
          expect(mail_body).to include("Accedi con l'SSO della tua organizzazione")
          expect(mail.body).not_to include('/auth/sign_in')
        end
      end
    end

    context 'when account does not have SAML enabled' do
      context 'when user has inviter' do
        let(:inviter_val) { create(:user, :administrator, skip_confirmation: true, account: account) }

        it 'shows standard invitation without SSO references' do
          expect(mail_body).to include("Sei stato invitato a unirti a #{account.name}")
          expect(mail_body).to include("#{inviter_val.name} ti ha invitato a unirti allo spazio di lavoro #{account.name} su")
          expect(mail_body).not_to include('Single Sign-On (SSO)')
          expect(mail_body).not_to include('Usa il portale SSO della tua organizzazione')
        end

        it 'shows password reset link' do
          expect(mail.body).to include('app/auth/password/edit')
        end
      end

      context 'when user has no inviter' do
        it 'shows the standard confirmation state' do
          expect(mail_body).to include('Conferma la tua email per iniziare')
          expect(mail_body).to include('Dobbiamo solo verificare il tuo indirizzo email prima che tu possa iniziare a usare il tuo account.')
          expect(mail_body).to include('Conferma il mio account')
        end

        it 'shows confirmation link' do
          expect(mail.body).to include("app/auth/confirmation?confirmation_token=#{confirmable_user.confirmation_token}")
        end
      end

      context 'when user is already confirmed' do
        let(:inviter_val) { create(:user, :administrator, skip_confirmation: true, account: account) }

        before do
          confirmable_user.confirm
        end

        it 'shows regular login link' do
          expect(mail_body).to include('Il tuo account e pronto')
          expect(mail.body).to include('/auth/sign_in')
          expect(mail_body).not_to include('SSO portal')
        end
      end

      context 'when user updates email' do
        before do
          confirmable_user.update!(email: 'updated@example.com')
        end

        it 'shows confirmation link for email verification' do
          expect(mail_body).to include('Conferma il tuo nuovo indirizzo email')
          expect(mail.body).to include('app/auth/confirmation?confirmation_token')
          expect(confirmable_user.unconfirmed_email.blank?).to be false
        end
      end
    end
  end
end
