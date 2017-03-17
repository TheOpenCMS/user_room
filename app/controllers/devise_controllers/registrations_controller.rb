class DeviseControllers::RegistrationsController < Devise::RegistrationsController
  layout 'user_room'

  before_action :configure_sign_up_params, only: [:create]

  def create_email_registration_request
    _email       = params[:email].to_s.strip
    callback_path = params[:callback_path]

    user       = ::User.where(email: _email).first
    reg_req    = ::EmailRegistrationRequest.where("email = ? AND created_at > ?", _email, 1.hour.ago).first
    used_email = user.present? || reg_req.present?

    if used_email || _email.blank? || !_email.match(/@/)
      redirect_back fallback_location: root_path,
        alert: 'Данный email невозможно использовать для запроса на регистрацию. Возможно он не корректен или уже использован.'
    else
      reg_req = ::EmailRegistrationRequest.create(email: params[:email])
      ::DeviseMailer.mail_registration_request(reg_req.id, callback_path).deliver
      redirect_back fallback_location: root_path,
        notice: 'Запрос на регистрацию создан. Проверьте ваш почтовый ящик'
    end
  end

  def activate_email_registration_request
    uid = params[:uid].to_s.downcase
    callback_path = params[:callback_path]

    reg_req = ::EmailRegistrationRequest.where(uid: uid).first

    unless reg_req
      return redirect_to root_path, alert: 'Запрос на регистрацию не обнаружен'
    end

    used_email = ::User.where(email: reg_req.email).first

    if used_email
      return redirect_to root_path, alert: 'Запрос уже активирован'
    end

    pass = ::Digest::MD5.hexdigest("#{ Time.now }-#{ rand }")[0...8]
    user = ::User.new(email: reg_req.email, password: pass)

    user.skip_confirmation!
    user.save!
    sign_in user

    ::UserRoomLogger.new_user_created(user.id)

    next_page = callback_path.present? ? callback_path : cabinet_path
    redirect_to next_page, notice: 'Поздравляем! Вы зарегистрированы на сайте'
  end

  protected

  # The path used after sign up.
  def after_sign_up_path_for(resource)
    cabinet_path
  end

  # The path used after sign up for inactive accounts.
  def after_inactive_sign_up_path_for(resource)
    root_path
  end
end
