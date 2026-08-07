# Reference Patterns (from fizzy codebase)

Patterns extracted from `/Users/juan/code/mine/fizzy` for adoption in MayStore.

## Controller Patterns

### Slim ApplicationController with Concerns

```ruby
class ApplicationController < ActionController::Base
  include Authentication
  include Authorization
  include CurrentRequest
  include SetPlatform
  include TurboFlash
end
```

Each responsibility is a separate concern — keeps the base controller under 15 lines.

### Resource Scoping Concerns

```ruby
# app/controllers/concerns/board_scoped.rb
module BoardScoped
  extend ActiveSupport::Concern
  included do
    before_action :set_board
  end
  private
    def set_board
      @board = Current.account.boards.find(params[:board_id])
    end
end
```

### TurboFlash Concern

Helper for flash messages in Turbo Stream responses:

```ruby
def turbo_stream_flash(**flash_options)
  turbo_stream.replace(:flash, partial: "layouts/shared/flash", locals: { flash: flash_options })
end
```

### Strong Params with wrap_parameters

```ruby
wrap_parameters :card, include: %i[ title description image ]
```

## Model Patterns

### Concerns by Behavior

One concern = one behavior. Each in its own file under `app/models/model_name/concern.rb`:

```ruby
class Card < ApplicationRecord
  include Closeable, Assignable, Taggable, Searchable, Broadcastable
end
```

### State Change Pattern

Wrap state changes in transactions, track events:

```ruby
module Card::Closeable
  def close(user: Current.user)
    transaction do
      not_now&.destroy
      create_closure! user: user
      track_event :closed, creator: user
    end
  end
end
```

### Idempotent Operations

Use create + rescue for idempotency:

```ruby
def assign(user)
  assignment = assignments.create(assignee: user)
  watch_by user if assignment.persisted?
rescue ActiveRecord::RecordNotUnique
  # Already assigned
end
```

### Eventable Audit Trail

```ruby
def track_event(action, creator: Current.user, **particulars)
  board.events.create!(
    action: "#{eventable_prefix}_#{action}",
    creator:, eventable: self, particulars:
  )
end
```

## Turbo/Hotwire Patterns

### Morph Broadcasts

```ruby
# Class-level declaration
broadcasts_refreshes
broadcasts_refreshes_to ->(board) { [ board.account, :all_boards ] }

# Manual refresh
broadcast_refresh_to "channel_name"
```

### Turbo Stream DOM Targeting

Use model + action key for smart targeting:

```erb
<%= turbo_stream.before [ @card, :new_comment ], partial: "comments/comment" %>
<%= turbo_stream.update [ @card, :new_comment ], partial: "comments/new" %>
```

### Morph in Controller Responses

```ruby
def render_card_replacement
  render turbo_stream: turbo_stream.replace(
    [ @card, :card_container ],
    partial: "cards/container",
    method: :morph,
    locals: { card: @card.reload }
  )
end
```

### Lazy Loading with IntersectionObserver

```javascript
// Stimulus controller that fetches content when element becomes visible
const observer = new IntersectionObserver((entries) => {
  if (entries.find(entry => entry.isIntersecting)) {
    get(this.urlValue, { responseKind: "turbo-stream" })
  }
})
observer.observe(this.element)
```

## View Patterns

### Permanent Elements in Layout

```erb
<footer id="footer">
  <div id="footer_frames" data-turbo-permanent="true">
    <%= render "bar/bar" %>
  </div>
</footer>
```

Elements with `data-turbo-permanent` survive Turbo navigations.

### CSS Custom Properties for Dynamic Styling

```ruby
def card_article_tag(card, &block)
  tag.article(
    style: "--card-color: #{card.color}; view-transition-name: #{dom_id(card)}",
    &block
  )
end
```

### Fragment Caching

```erb
<%= cache card do %>
  <%= render "cards/content", card: card %>
<% end %>
```

## CSS Organization

### Layer-Based Architecture

```css
@layer reset, base, components, modules, utilities, native, platform;
```

- `native` layer for Turbo Native app styles
- `platform` layer for iOS/Android-specific overrides
- Feature-based files (one CSS file per feature)

### Platform-Specific Styles

```css
/* native.css */
[data-platform~=native] .hide-on-native { display: none; }

/* ios.css */
[data-platform~=ios] { /* iOS overrides */ }

/* android.css */
[data-platform~=android] { /* Android overrides */ }
```

### Safe Area Insets

```css
:root {
  --custom-safe-inset-top: var(--injected-safe-inset-top, env(safe-area-inset-top, 0px));
  --custom-safe-inset-bottom: var(--injected-safe-inset-bottom, env(safe-area-inset-bottom, 0px));
}
```

## Test Patterns

### Test Helper Setup

```ruby
class ActiveSupport::TestCase
  fixtures :all
  include ActiveJob::TestHelper
  include Turbo::Broadcastable::TestHelper

  setup { Current.account = accounts("default") }
  teardown { Current.clear_all }
end
```

### Testing Concerns in Isolation

```ruby
class Card::CloseableTest < ActiveSupport::TestCase
  test "close cards" do
    assert_not cards(:logo).closed?
    assert_difference -> { cards(:logo).events.count }, +1 do
      cards(:logo).close(user: users(:kevin))
    end
    assert cards(:logo).closed?
  end
end
```

## JavaScript Patterns

### Platform Detection Helpers

```javascript
export function isNative() { return /Hotwire Native/.test(navigator.userAgent) }
export function isMobile() { return isIos() || isAndroid() }
export function isIos() { return /iPhone|iPad/.test(navigator.userAgent) }
export function isAndroid() { return /Android/.test(navigator.userAgent) }
```

### Bridge Controllers

Located in `app/javascript/controllers/bridge/`:
- `title_controller.js` — sync page title to native nav bar
- `buttons_controller.js` — map HTML buttons to native buttons
- `insets_controller.js` — receive safe area insets from native app
- `form_controller.js` — form submission via native interface
