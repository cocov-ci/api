# frozen_string_literal: true

class SessionController < ApplicationController
  def begin_authentication
    raw_redirect_uri = params[:redirect]
    error! :session, :no_redirect if raw_redirect_uri.blank?
    redirect_uri = begin
      URI.parse(raw_redirect_uri)
    rescue URI::InvalidURIError
      error! :session, :bad_redirect_uri
    end

    keys = Cocov::Redis.make_authentication_keys
    redirect_params = Rack::Utils.parse_nested_query(redirect_uri.query)
    redirect_params["exchange_token"] = keys[:id]
    redirect_uri.query = redirect_params.to_param

    query_params = {
      client_id: Cocov::GITHUB_OAUTH_CLIENT_ID,
      redirect_uri: redirect_uri.to_s,
      state: keys[:state],
      scope: "user:email,repo",
      allow_signup: false
    }

    render json: { redirect_to: "https://github.com/login/oauth/authorize?#{query_params.to_param}" }
  end

  def exchange
    exchange_token = params[:exchange_token]
    state = params[:state]
    code = params[:code]
    redirect = params[:redirect]
    error! :session, :no_exchange_token if exchange_token.blank?
    error! :session, :no_state if state.blank?
    error! :session, :no_code if code.blank?
    error! :session, :no_redirect if redirect.blank?

    stored_state = Cocov::Redis.get_authentication_state(exchange_token)
    error! :session, :invalid_exchange_token_or_state if stored_state != state

    exchanged = Cocov::GitHub.exchange_access_code(code, redirect)
    usr = Cocov::GitHub.for_user(exchanged[:access_token])
    usr_login = usr.user.login

    case Cocov::GitHub.user_membership(usr_login)
    when :outside_collaborator
      error! :session, :outside_collaborator_not_allowed unless Cocov::ALLOW_OUTSIDE_COLLABORATORS
    when :not_a_member
      error! :session, :not_an_org_member
    end

    user = User.with_github_data! usr.user, exchanged
    UpdateUserPermissionsJob.perform_later(user.id)
    auth = user.make_auth_token!

    render json: {
      token: auth.value,
      name: usr_login,
      admin: user.admin
    }
  end
end
