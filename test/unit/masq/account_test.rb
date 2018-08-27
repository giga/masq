# encoding: utf-8

require 'test_helper'

module Masq
  class AccountTest < ActiveSupport::TestCase
    fixtures :accounts

    def setup
      @account = Account.new valid_account_attributes
    end

    def test_should_require_login
      @account.login = nil
      assert_invalid @account, :login
    end

    def test_should_require_login_with_minimum_length_of_3_characters
      @account.login = "de"
      assert_invalid @account, :login
    end

    def test_should_require_login_without_whitespaces
      @account.login = "Tester Test"
      assert_invalid @account, :login
    end

    def test_should_require_login_without_umlauts
      @account.login = "Täster"
      assert_invalid @account, :login
    end

    def test_should_require_email
      @account.email = nil
      assert_invalid @account, :email
    end

    def test_should_require_valid_email
      @account.email = "test"
      assert_equal false, @account.valid?
      assert @account.errors[:email]
      @account.email = "test@hotmail"
      assert_equal false, @account.valid?
      assert @account.errors[:email]
      @account.email = "test@bla.com"
      assert_valid @account
    end

    def test_should_require_password
      @account.password = nil
      assert_invalid @account, :password
    end

    def test_should_require_password_confirmation
      @account.password_confirmation = nil
      assert_invalid @account, :password_confirmation
      valid_password = "1234567"
      @account.password = valid_password
      @account.password_confirmation = "123456"
      assert_invalid @account, :password
      @account.password_confirmation = valid_password
      assert_valid @account
    end

    def test_should_require_password_with_minimum_length_of_6_characters
      @account.password = "dere8"
      assert_invalid @account, :password
      valid_password = "dere84"
      @account.password = valid_password
      @account.password_confirmation = valid_password
      assert_valid @account
    end

    def test_should_create_account_on_demand_if_create_auth_ondemand_is_enabled
      Masq::Engine.config.masq['create_auth_ondemand']['enabled'] = true
      Masq::Engine.config.masq['create_auth_ondemand']['default_mail_domain'] = "example.net"
      Account.authenticate('notexistingtestuser', 'somepassword')
      account = Account.find_by_login('notexistingtestuser')
      assert account.kind_of? Account
      assert_equal 'notexistingtestuser', account.login
      assert_equal 'notexistingtestuser@example.net', account.email
    end

    def test_should_find_and_activate_by_activation_token
      @account.update!(:activation_code, 'openid123')
      assert_equal false, @account.active?
      Account.find_and_activate!('openid123')
      @account.reload
      assert @account.active?
      assert_not_nil @account.activated_at
    end

    def test_should_reset_password
      Masq::Engine.config.masq['trust_basic_auth'] = false # doesn't make sense without
      accounts(:standard).update!(:password => 'new password', :password_confirmation => 'new password')
      assert_equal accounts(:standard), Account.authenticate('quentin', 'new password')
    end

    def test_should_not_rehash_password
      Masq::Engine.config.masq['trust_basic_auth'] = false # doesn't make sense without
      accounts(:standard).update_attributes(:login => 'quentin2')
      assert_equal accounts(:standard), Account.authenticate('quentin2', 'test')
    end

    def test_should_authenticate_user
      Masq::Engine.config.masq['trust_basic_auth'] = false # doesn't make sense without
      assert_equal accounts(:standard), Account.authenticate('quentin', 'test')
    end

    def test_should_not_check_password_if_trust_basic_auth_is_enabled_and_basic_is_used
      Masq::Engine.config.masq['trust_basic_auth'] = true
      assert_equal accounts(:standard), Account.authenticate('quentin', 'nottest', true)
    end

    def test_should_check_password_if_trust_basic_auth_is_enabled_and_basic_is_not_used
      Masq::Engine.config.masq['trust_basic_auth'] = true
      assert_not_equal accounts(:standard), Account.authenticate('quentin', 'nottest', false)
    end

    def test_should_check_password_if_trust_basic_auth_is_disabled
      Masq::Engine.config.masq['trust_basic_auth'] = false
      assert_not_equal accounts(:standard), Account.authenticate('quentin', 'nottest', true)
      assert_not_equal accounts(:standard), Account.authenticate('quentin', 'nottest', false)
      assert_equal accounts(:standard), Account.authenticate('quentin', 'test', true)
    end

    def test_should_not_login_if_trust_basic_auth_is_enabled_but_account_is_disabled
      Masq::Engine.config.masq['trust_basic_auth'] = true
      account = accounts(:standard)
      account.activation_code = 666
      account.activated_at = nil
      account.save!
      assert_not_equal account, Account.authenticate('quentin', 'test')
    end

    def test_should_create_random_password_on_create_account_on_demand_if_create_auth_ondemand_is_enabled_and_random_password_is_enabled
      Masq::Engine.config.masq['create_auth_ondemand']['enabled'] = true
      Masq::Engine.config.masq['create_auth_ondemand']['default_mail_domain'] = "example.net"
      Masq::Engine.config.masq['create_auth_ondemand']['random_password'] = true
      Account.authenticate('notexistingtestuser', 'somepassword')
      account = Account.find_by_login('notexistingtestuser')
      assert_not_equal account.encrypt('somepassword'), account.crypted_password
    end

    def test_should_create_random_password_on_create_account_on_demand_if_create_auth_ondemand_is_enabled_and_random_password_is_disabled
      Masq::Engine.config.masq['create_auth_ondemand']['enabled'] = true
      Masq::Engine.config.masq['create_auth_ondemand']['default_mail_domain'] = "example.net"
      Masq::Engine.config.masq['create_auth_ondemand']['random_password'] = false
      Account.authenticate('notexistingtestuser', 'somepassword')
      account = Account.find_by_login('notexistingtestuser')
      assert_equal account.encrypt('somepassword'), account.crypted_password
    end

    def test_should_set_remember_token
      accounts(:standard).remember_me
      assert_not_nil accounts(:standard).remember_token
      assert_not_nil accounts(:standard).remember_token_expires_at
    end

    def test_should_unset_remember_token
      accounts(:standard).remember_me
      assert_not_nil accounts(:standard).remember_token
      accounts(:standard).forget_me
      assert_nil accounts(:standard).remember_token
    end

    def test_should_remember_me_for_one_week
      before = 1.week.from_now.utc
      accounts(:standard).remember_me_for 1.week
      after = 1.week.from_now.utc
      assert_not_nil accounts(:standard).remember_token
      assert_not_nil accounts(:standard).remember_token_expires_at
      assert accounts(:standard).remember_token_expires_at.between?(before, after)
    end

    def test_should_remember_me_until_one_week
      time = 1.week.from_now.utc
      accounts(:standard).remember_me_until time
      assert_not_nil accounts(:standard).remember_token
      assert_not_nil accounts(:standard).remember_token_expires_at
      assert_equal accounts(:standard).remember_token_expires_at, time
    end

    def test_should_remember_me_default_two_weeks
      before = 2.weeks.from_now.utc
      accounts(:standard).remember_me
      after = 2.weeks.from_now.utc
      assert_not_nil accounts(:standard).remember_token
      assert_not_nil accounts(:standard).remember_token_expires_at
      assert accounts(:standard).remember_token_expires_at.between?(before, after)
    end

    def test_should_delete_associated_personas_on_destroy
      @account.save
      @persona = @account.personas.create(valid_persona_attributes)
      assert_equal 1, @account.personas.size
      @account.destroy
      assert_nil Persona.find_by_id(@persona.id)
    end

    def test_should_delete_associated_sites_on_destroy
      @account.save
      @site = @account.sites.create(valid_site_attributes)
      assert_equal 1, @account.sites.size
      @account.destroy
      assert_nil Site.find_by_id(@site.id)
    end

    def test_should_get_associated_with_a_yubikey_if_the_given_otp_is_correct
      @account = accounts(:standard)
      yubico_otp = 'x' * 44
      assert @account.yubico_identity.nil?
      Account.expects(:verify_yubico_otp).with(yubico_otp).returns(true)
      @account.associate_with_yubikey(yubico_otp)
      @account.reload
      assert_equal yubico_otp[0..11], @account.yubico_identity
    end

    def test_should_be_able_to_authenticate_with_a_yubikey_if_it_matches_the_yubico_identity
      @account = accounts(:standard)
      yubico_otp = 'x' * 44
      @account.yubico_identity = yubico_otp[0..11]
      assert @account.save
      Account.expects(:verify_yubico_otp).with(yubico_otp).returns(true)
      assert @account.yubikey_authenticated?(yubico_otp)
    end

    def test_should_not_be_able_to_authenticate_with_a_yubikey_if_can_use_yubikey_is_disabled
      Masq::Engine.config.masq['can_use_yubikey'] = false
      @account = accounts(:standard)
      yubico_otp = 'x' * 44
      @account.yubico_identity = yubico_otp[0..11]
      @account.yubikey_mandatory = true
      assert @account.save
      assert (not @account.authenticated?("test" + yubico_otp))
    end

    def test_should_not_be_able_to_authenticate_with_a_yubikey_if_it_does_not_match_the_yubico_identity
      Masq::Engine.config.masq['can_use_yubikey'] = true # makes no sense without
      @account = accounts(:standard)
      yubico_otp = 'x' * 44
      @account.yubico_identity = 'y' * 12
      assert @account.save
      Account.expects(:verify_yubico_otp).with(yubico_otp).returns(true)
      assert !@account.yubikey_authenticated?(yubico_otp)
    end

    def test_should_split_password_and_yubico_otp
      password, yubico_otp = '123456', ('x' * 22 + 'y' * 22)
      token = password + yubico_otp
      assert_equal [password, yubico_otp], Account.split_password_and_yubico_otp(token)
    end

  end
end
