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

    # Capybara clicks a button as soon as it exists in the DOM, but a button
    # whose only behaviour is a Stimulus action does nothing until its
    # controller has connected, and the click is not replayed afterwards. The
    # test then waits for an effect that will never happen. Wait for the
    # controller instance before clicking anything that only Stimulus handles.
    def wait_for_stimulus(identifier)
      selector = "[data-controller~='#{identifier}']"
      assert_selector selector, visible: :all

      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
      until stimulus_connected?(identifier, selector)
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          raise Capybara::ExpectationNotMet, "Stimulus controller #{identifier} never connected"
        end
        sleep 0.05
      end
    end

    def stimulus_connected?(identifier, selector)
      page.evaluate_script(<<~JS)
        Boolean(window.Stimulus && window.Stimulus.getControllerForElementAndIdentifier(
          document.querySelector(#{selector.to_json}), #{identifier.to_json}
        ))
      JS
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
end
