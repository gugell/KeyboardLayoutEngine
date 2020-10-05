//
//  CustomKeyboard.swift
//  KeyboardLayoutEngine
//
//  Created by Cem Olcay on 11/05/16.
//  Copyright © 2016 Prototapp. All rights reserved.
//

import UIKit

// MARK: - CustomKeyboardDelegate
public protocol CustomKeyboardDelegate: class {
    func customKeyboard(_ customKeyboard: CustomKeyboard, keyboardButtonPressed keyboardButton: KeyboardButton)
    func customKeyboard(_ customKeyboard: CustomKeyboard, keyButtonPressed key: String)
    func customKeyboardSpaceButtonPressed(_ customKeyboard: CustomKeyboard)
    func customKeyboardBackspaceButtonPressed(_ customKeyboard: CustomKeyboard)
    func customKeyboardGlobeButtonPressed(_ customKeyboard: CustomKeyboard)
    func customKeyboardReturnButtonPressed(_ customKeyboard: CustomKeyboard)
}

extension CustomKeyboardDelegate {
    func customKeyboardGlobeButtonPressed(_ customKeyboard: CustomKeyboard) { }
}

// MARK: - CustomKeyboard
public class CustomKeyboard: UIView, KeyboardLayoutDelegate {
    
    public var keyboardLayout = CustomKeyboardLayout()
    public weak var delegate: CustomKeyboardDelegate?
    
    // MARK: CustomKeyobardShiftState
    public enum CustomKeyboardShiftState {
        case Once
        case Off
        case On
    }
    
    // MARK: CustomKeyboardLayoutState
    public enum CustomKeyboardLayoutState {
        case Letters(shiftState: CustomKeyboardShiftState)
        case Numbers
        case Symbols
    }
    
    public private(set) var keyboardLayoutState: CustomKeyboardLayoutState = .Letters(shiftState: CustomKeyboardShiftState.Once) {
        didSet {
            keyboardLayoutStateDidChange(oldState: oldValue, newState: keyboardLayoutState)
        }
    }
    
    // MARK: Shift
    public var shiftToggleInterval: TimeInterval = 0.5
    private var shiftToggleTimer: Timer?
    
    // MARK: Backspace
    public var backspaceDeleteInterval: TimeInterval = 0.1
    public var backspaceAutoDeleteModeInterval: TimeInterval = 0.5
    private var backspaceDeleteTimer: Timer?
    private var backspaceAutoDeleteModeTimer: Timer?
    
    // MARK: KeyMenu
    public var keyMenuLocked: Bool = false
    public var keyMenuOpenTimer: Timer?
    public var keyMenuOpenTimeInterval: TimeInterval = 1
    public var keyMenuShowingKeyboardButton: KeyboardButton? {
        didSet {
            oldValue?.showKeyPop(show: false)
            oldValue?.showKeyMenu(show: false)
            keyMenuShowingKeyboardButton?.showKeyPop(show: false)
            keyMenuShowingKeyboardButton?.showKeyMenu(show: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [unowned self] in
                self.getCurrentKeyboardLayout().typingEnabled = self.keyMenuShowingKeyboardButton == nil && self.keyMenuLocked == false
            }
            
        }
    }
    
    // MARK: Init
    public init() {
        super.init(frame: CGRect.zero)
        defaultInit()
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        defaultInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        defaultInit()
    }
    
    private func defaultInit() {
        keyboardLayout = CustomKeyboardLayout()
        keyboardLayoutStateDidChange(oldState: nil, newState: keyboardLayoutState)
    }
    
    // MARK: Layout
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        getCurrentKeyboardLayout().frame = CGRect(
            x: 0,
            y: 0,
            width: frame.size.width,
            height: frame.size.height)
    }
    
    // MARK: KeyboardLayout
    public func getKeyboardLayout(ofState state: CustomKeyboardLayoutState) -> KeyboardLayout {
        switch state {
        case .Letters(let shiftState):
            switch shiftState {
            case .Once:
                return keyboardLayout.uppercase
            case .On:
                return keyboardLayout.uppercaseToggled
            case .Off:
                return keyboardLayout.lowercase
            }
        case .Numbers:
            return keyboardLayout.numbers
        case .Symbols:
            return keyboardLayout.symbols
        }
    }
    
    public func getCurrentKeyboardLayout() -> KeyboardLayout {
        return getKeyboardLayout(ofState: keyboardLayoutState)
    }
    
    public func enumerateKeyboardLayouts(enumerate: (KeyboardLayout) -> Void) {
        let layouts = [
            keyboardLayout.uppercase,
            keyboardLayout.uppercaseToggled,
            keyboardLayout.lowercase,
            keyboardLayout.numbers,
            keyboardLayout.symbols,
        ]
        
        for layout in layouts {
            enumerate(layout)
        }
    }
    
    public func keyboardLayoutStateDidChange(oldState: CustomKeyboardLayoutState?, newState: CustomKeyboardLayoutState) {
        // Remove old keyboard layout
        if let oldState = oldState {
            let oldKeyboardLayout = getKeyboardLayout(ofState: oldState)
            oldKeyboardLayout.delegate = nil
            oldKeyboardLayout.removeFromSuperview()
        }
        
        // Add new keyboard layout
        let newKeyboardLayout = getKeyboardLayout(ofState: newState)
        newKeyboardLayout.delegate = self
        addSubview(newKeyboardLayout)
        setNeedsLayout()
    }
    
    public func reload() {
        // Remove current
        let currentLayout = getCurrentKeyboardLayout()
        currentLayout.delegate = nil
        currentLayout.removeFromSuperview()
        // Reload layout
        keyboardLayout = CustomKeyboardLayout()
        keyboardLayoutStateDidChange(oldState: nil, newState: keyboardLayoutState)
    }
    
    // MARK: Capitalize
    public func switchToLetters(shiftState shift: CustomKeyboardShiftState) {
        keyboardLayoutState = .Letters(shiftState: shift)
    }
    
    public func capitalize() {
        switchToLetters(shiftState: .Once)
    }
    
    // MARK: Backspace Auto Delete
    private func startBackspaceAutoDeleteModeTimer() {
        backspaceAutoDeleteModeTimer = Timer.scheduledTimer(
            timeInterval: backspaceAutoDeleteModeInterval,
            target: self,
            selector: #selector(CustomKeyboard.startBackspaceAutoDeleteMode),
            userInfo: nil,
            repeats: false)
    }
    
    private func startBackspaceDeleteTimer() {
        backspaceDeleteTimer = Timer.scheduledTimer(
            timeInterval: backspaceDeleteInterval,
            target: self,
            selector: #selector(CustomKeyboard.autoDelete),
            userInfo: nil,
            repeats: true)
    }
    
    private func invalidateBackspaceAutoDeleteModeTimer() {
        backspaceAutoDeleteModeTimer?.invalidate()
        backspaceAutoDeleteModeTimer = nil
    }
    
    private func invalidateBackspaceDeleteTimer() {
        backspaceDeleteTimer?.invalidate()
        backspaceDeleteTimer = nil
    }
    
    @objc internal func startBackspaceAutoDeleteMode() {
        invalidateBackspaceDeleteTimer()
        startBackspaceDeleteTimer()
    }
    
    @objc internal func autoDelete() {
        delegate?.customKeyboardBackspaceButtonPressed(self)
    }
    
    // MARK: Shift Toggle
    private func startShiftToggleTimer() {
        shiftToggleTimer = Timer.scheduledTimer(
            timeInterval: shiftToggleInterval,
            target: self,
            selector: #selector(CustomKeyboard.invalidateShiftToggleTimer),
            userInfo: nil,
            repeats: false)
    }
    
    @objc internal func invalidateShiftToggleTimer() {
        shiftToggleTimer?.invalidate()
        shiftToggleTimer = nil
    }
    
    // MARK: KeyMenu Toggle
    private func startKeyMenuOpenTimer(forKeyboardButton keyboardButton: KeyboardButton) {
        keyMenuOpenTimer = Timer.scheduledTimer(timeInterval:
            keyMenuOpenTimeInterval,
                                                target: self,
                                                selector: #selector(CustomKeyboard.openKeyMenu(_:)),
                                                userInfo: keyboardButton,
                                                repeats: false)
    }
    
    private func invalidateKeyMenuOpenTimer() {
        keyMenuOpenTimer?.invalidate()
        keyMenuOpenTimer = nil
    }
    
    @objc public func openKeyMenu(_ timer: Timer) {
        if let userInfo = timer.userInfo, let keyboardButton = userInfo as? KeyboardButton {
            keyMenuShowingKeyboardButton = keyboardButton
        }
    }
    
    // MARK: KeyboardLayoutDelegate
    public func keyboardLayout(_ keyboardLayout: KeyboardLayout, didKeyPressStart keyboardButton: KeyboardButton) {
        invalidateBackspaceAutoDeleteModeTimer()
        invalidateBackspaceDeleteTimer()
        invalidateKeyMenuOpenTimer()
        
        // Backspace
        if keyboardButton.identifier == CustomKeyboardIdentifier.Backspace.rawValue {
            startBackspaceAutoDeleteModeTimer()
        }
        
        // KeyPop and KeyMenu
        if keyboardButton.style.keyPopType != nil {
            keyboardButton.showKeyPop(show: true)
            if keyboardButton.keyMenu != nil {
                startKeyMenuOpenTimer(forKeyboardButton: keyboardButton)
            }
        } else if keyboardButton.keyMenu != nil {
            keyMenuShowingKeyboardButton = keyboardButton
            keyMenuLocked = false
        }
    }
    
    public func keyboardLayout(_ keyboardLayout: KeyboardLayout, didKeyPressEnd keyboardButton: KeyboardButton) {
        delegate?.customKeyboard(self, keyboardButtonPressed: keyboardButton)
        
        // If keyboard key is pressed notify no questions asked
        if case KeyboardButtonType.Key(let text) = keyboardButton.type {
            delegate?.customKeyboard(self, keyButtonPressed: text)
            
            // If shift state was CustomKeyboardShiftState.Once then make keyboard layout lowercase
            if case CustomKeyboardLayoutState.Letters(let shiftState) = keyboardLayoutState, shiftState == .Once {
                keyboardLayoutState = CustomKeyboardLayoutState.Letters(shiftState: .Off)
                return
            }
        }
        
        // Chcek special keyboard buttons
        if let keyId = keyboardButton.identifier, let identifier = CustomKeyboardIdentifier(rawValue: keyId) {
            switch identifier {
                
            // Notify special keys
            case .Backspace:
                delegate?.customKeyboardBackspaceButtonPressed(self)
            case .Space:
                delegate?.customKeyboardSpaceButtonPressed(self)
            case .Globe:
                delegate?.customKeyboardGlobeButtonPressed(self)
            case .Return:
                delegate?.customKeyboardReturnButtonPressed(self)
                
            // Update keyboard layout state
            case .Letters:
                keyboardLayoutState = .Letters(shiftState: .Off)
            case .Numbers:
                keyboardLayoutState = .Numbers
            case .Symbols:
                keyboardLayoutState = .Symbols
                
            // Update shift state
            case .ShiftOff:
                if shiftToggleTimer == nil {
                    keyboardLayoutState = .Letters(shiftState: .Once)
                    startShiftToggleTimer()
                } else {
                    keyboardLayoutState = .Letters(shiftState: .On)
                    invalidateShiftToggleTimer()
                }
            case .ShiftOnce:
                if shiftToggleTimer == nil {
                    keyboardLayoutState = .Letters(shiftState: .Off)
                    startShiftToggleTimer()
                } else {
                    keyboardLayoutState = .Letters(shiftState: .On)
                    invalidateShiftToggleTimer()
                }
            case .ShiftOn:
                if shiftToggleTimer == nil {
                    keyboardLayoutState = .Letters(shiftState: .Off)
                }
            }
        }
    }
    
    public func keyboardLayout(_ keyboardLayout: KeyboardLayout, didTouchesBegin touches: Set<UITouch>) {
        // KeyMenu
        if let menu = keyMenuShowingKeyboardButton?.keyMenu,let touch = touches.first {
            menu.updateSelection(touchLocation: touch.location(in: self), inView: self)
        }
    }
    
    public func keyboardLayout(_ keyboardLayout: KeyboardLayout, didTouchesMove touches: Set<UITouch>) {
        // KeyMenu
        if let menu = keyMenuShowingKeyboardButton?.keyMenu, let touch = touches.first {
            menu.updateSelection(touchLocation: touch.location(in: self), inView: self)
        }
    }
    
    public func keyboardLayout(_ keyboardLayout: KeyboardLayout, didTouchesEnd touches: Set<UITouch>?)  {
        invalidateBackspaceAutoDeleteModeTimer()
        invalidateBackspaceDeleteTimer()
        invalidateKeyMenuOpenTimer()
        
        // KeyMenu
        if let menu = keyMenuShowingKeyboardButton?.keyMenu, let touch = touches?.first {
            menu.updateSelection(touchLocation: touch.location(in: self), inView: self)
            // select item
            if menu.selectedIndex >= 0 {
                if let item = menu.items[safe: menu.selectedIndex] {
                    item.action?(item)
                }
                keyMenuShowingKeyboardButton = nil
                keyMenuLocked = false
            } else {
                if keyMenuLocked {
                    keyMenuShowingKeyboardButton = nil
                    keyMenuLocked = false
                    return
                }
                keyMenuLocked = true
            }
        }
    }
    
    public func keyboardLayout(_ keyboardLayout: KeyboardLayout, didTouchesCancel touches: Set<UITouch>?) {
        invalidateBackspaceAutoDeleteModeTimer()
        invalidateBackspaceDeleteTimer()
        invalidateKeyMenuOpenTimer()
        
        // KeyMenu
        if let menu = keyMenuShowingKeyboardButton?.keyMenu, let touch = touches?.first {
            menu.updateSelection(touchLocation: touch.location(in: self), inView: self)
            // select item
            if menu.selectedIndex >= 0 {
                if let item = menu.items[safe: menu.selectedIndex] {
                    item.action?(item)
                }
                keyMenuShowingKeyboardButton = nil
                keyMenuLocked = false
            } else {
                if keyMenuLocked {
                    keyMenuShowingKeyboardButton = nil
                    keyMenuLocked = false
                    getCurrentKeyboardLayout().typingEnabled = true
                    return
                }
                keyMenuLocked = true
            }
        }
    }
    
    public func keyboardLayout(_ keyboardLayout: KeyboardLayout, didDraggedInFrom oldKeyboardButton: KeyboardButton, to newKeyboardButton: KeyboardButton) {
        
    }
}
