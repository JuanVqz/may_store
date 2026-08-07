require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    # The app resolves the store from the subdomain, so tests have to browse a
    # real hostname rather than 127.0.0.1. This makes Chrome resolve every host
    # to the Capybara server, so `cafe-delicias.example.com` works the same on a
    # laptop and on CI without touching /etc/hosts or relying on *.localhost.
    options.add_argument("--host-resolver-rules=MAP * 127.0.0.1")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
  end

  teardown do
    Capybara.app_host = nil
  end

  private
    # Points the browser at a store and visits a path within it.
    def visit_store(store, path = "/")
      Capybara.app_host = "http://#{store.subdomain}.example.com:#{Capybara.current_session.server.port}"
      visit path
    end

    def sign_in_as(employee_number, store: stores(:cafe_delicias))
      visit_store(store, login_path)
      fill_in "employee_number", with: employee_number
      fill_in "password", with: PASSWORD
      click_on I18n.t("login.submit")
      assert_no_current_path login_path, wait: 5
    end

    def sign_in_waiter(store: stores(:cafe_delicias))
      sign_in_as accounts(:waiter_juan_account).employee_number, store: store
    end

    def sign_in_kitchen(store: stores(:cafe_delicias))
      sign_in_as accounts(:kitchen_carlos_account).employee_number, store: store
    end

    def sign_in_admin(store: stores(:cafe_delicias))
      sign_in_as accounts(:admin_account).employee_number, store: store
    end

    # button_to renders a form, so the clickable element is an input, not a link.
    def click_button_to(label)
      click_on label
    end

    def accept_confirm_and(&block)
      accept_confirm(&block)
    end
end
