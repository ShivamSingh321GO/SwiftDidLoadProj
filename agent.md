# AI Coding Rules

This file defines the engineering standards that every AI coding assistant must follow.

Failure to follow these instructions is considered an incorrect implementation.

---

# Project Goal

Build a production-quality SwiftUI application.

Priorities (highest to lowest):

1. Correctness
2. Readability
3. Native Apple UX
4. Performance
5. Scalability

Never sacrifice code quality for short code.

---

# General Rules

Always write code as if this project will ship to the App Store.

Do NOT generate demo-quality code.

Do NOT generate "quick hacks."

Never use force unwraps.

Never duplicate code.

Never leave TODO comments.

Never leave commented-out code.

Never ignore compiler warnings.

Always produce clean, compilable Swift.

---

# Architecture

Use MVVM.

Views should only display UI.

Business logic belongs inside ViewModels.

Networking belongs inside Services.

Data models belong inside Models.

Views should never perform networking.

Views should never decode JSON.

Views should never contain business logic.

---

# SwiftUI

Prefer native SwiftUI.

Avoid UIKit unless absolutely necessary.

Use:

NavigationStack

Sheet

FullScreenCover

Toolbar

Menu

ContextMenu

ConfirmationDialog

Alert

PhotosPicker

ShareLink

TipKit

Swift Charts

MapKit

Use Apple's Human Interface Guidelines.

---

# State Management

Use:

@State

@Binding

@Observable

@Environment

@EnvironmentObject only when truly global.

Do not create unnecessary Observable objects.

---

# Dependency Injection

Inject dependencies.

Never create services directly inside Views.

Preferred:

ViewModel(service:)

---

# Networking

Use:

async/await

URLSession

Codable

Result

Throw meaningful errors.

Never block the Main Thread.

Never use completion handlers unless necessary.

---

# Error Handling

Every possible failure should be handled.

Never ignore errors.

Display user-friendly error messages.

Never expose raw API errors.

---

# Loading States

Every async operation must support:

Loading

Success

Failure

Empty State

Never leave users wondering.

---

# UI Design

Use:

.largetitles, .title, .footnote, .body
dont use custom sizing like .font(.system(.size: 30)) -- avoide using this type of code

use SF Symbols

System colors

Dynamic Type

Accessibility

Animations

Proper spacing

Native Apple styling

---

# Performance

Avoid unnecessary redraws.

Avoid nested GeometryReaders.

Avoid expensive computed properties inside Views.

---

# Code Style

Meaningful variable names.

Meaningful function names.

Maximum function length: ~40 lines

Maximum file length: ~300 lines

Break large Views into Components.

Avoid massive files.

---

# Extensions

Never create unnecessary helpers.

---

# Reusable Components

Prefer reusable components.

Examples:

PrimaryButton

SecondaryButton

LoadingView

ErrorView

EmptyStateView

NetworkImage

AsyncButton

CardView

TagView

AvatarView

---

# Assets

Never hardcode colors.

Never hardcode fonts.

Never hardcode spacing.

Create constants.

---

# Animations

Prefer:

withAnimation()

matchedGeometryEffect

symbolEffect

contentTransition

Avoid unnecessary animations.

Animations should communicate state.

---

# AI Usage Rules

Before generating code:

Understand the existing architecture.

Do not rewrite unrelated files.

Modify only necessary files.

Respect existing naming.

Never break public APIs.

Always preserve functionality.

---

# Testing Before Completion

Before considering any task complete verify:

✓ Builds successfully

✓ No force unwraps

✓ No duplicated code

✓ Follows MVVM

✓ Proper error handling

✓ Accessibility considered

✓ Uses async/await

✓ SwiftUI native

✓ Clean architecture

---

# If Multiple Solutions Exist

Choose the solution that:

Requires the least maintenance.

Uses the newest stable Apple API.

Produces the simplest architecture.

Feels most "Apple."

---

# Final Rule

Whenever uncertain:

Choose the implementation that Apple engineers would likely choose for a production SwiftUI application.
