//
//  Control.swift
//  TGUIKit
//
//  Created by keepcoder on 25/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac

public enum ControlState {
    case Normal
    case Hover
    case Highlight
    case Other
}

public enum ControlEvent {
    case Down
    case Up
    case Click
    case SingleClick
    case RightClick
    case RightDown
    case MouseDragging
    case LongMouseDown
    case LongMouseUp
    case LongOver
}

private let longHandleDisposable = MetaDisposable()
private let longOverHandleDisposable = MetaDisposable()

open class Control: View {
    
    open var isEnabled:Bool = true {
        didSet {
            if isEnabled != oldValue {
                apply(state: controlState)
            }
        }
    }
    open var hideAnimated:Bool = false
    
    
    public var appTooltip: String?

    public var isSelected:Bool {
        didSet {
            if isSelected != oldValue {
                apply(state: isSelected ? .Highlight : self.controlState)
            }
            updateState()
        }
    }
    
    open var animationStyle:AnimationStyle = AnimationStyle(duration:0.3, function:CAMediaTimingFunctionName.spring)
    
    var trackingArea:NSTrackingArea?
    
    
    
    private var handlers:[(ControlEvent,(Control) -> Void)] = []
    private var stateHandlers:[(ControlState,(Control) -> Void)] = []
    
    private var backgroundState:[ControlState:NSColor] = [:]
    private var mouseMovedInside: Bool = true
    private var longInvoked: Bool = false
    open override var backgroundColor: NSColor {
        get{
            return self.style.backgroundColor
        }
        set {
            if self.style.backgroundColor != newValue {
                self.style.backgroundColor = newValue
                self.setNeedsDisplayLayer()
            }
        }
    }
    
    public var style:ControlStyle = ControlStyle() {
        didSet {
            if style != oldValue {
                apply(style:style)
            }
        }
    }
    
    open override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        apply(state: self.controlState)
        updateTrackingAreas()
    }
    
    public var controlState:ControlState = .Normal {
        didSet {
            if oldValue != controlState {
                apply(state: isSelected ? .Highlight : controlState)
                
                for (state,handler) in stateHandlers {
                    if state == controlState {
                        handler(self)
                    }
                }

                if let tp = appTooltip, controlState == .Hover {
                    tooltip(for: self, text: tp)
                }
            }
        }
    }
    
    public func apply(state:ControlState) -> Void {
        let state:ControlState = self.isSelected ? .Highlight : state
        if let color = backgroundState[state] {
            self.layer?.backgroundColor = color.cgColor
        } else {
            self.layer?.backgroundColor = backgroundState[.Normal]?.cgColor ?? self.backgroundColor.cgColor
        }
        if animates {
            self.layer?.animateBackground()
        }
    }
    
    private var mouseIsDown:Bool = false
    
    open override func updateTrackingAreas() {
        super.updateTrackingAreas();
        
        if let trackingArea = trackingArea {
            self.removeTrackingArea(trackingArea)
        }
        
        trackingArea = nil
        
        if let _ = window {
            let options:NSTrackingArea.Options = [NSTrackingArea.Options.cursorUpdate, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.mouseMoved, NSTrackingArea.Options.activeInKeyWindow, NSTrackingArea.Options.inVisibleRect]
            self.trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
            
            self.addTrackingArea(self.trackingArea!)
        }
        
    }
    
    open override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    open override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        updateTrackingAreas()
    }
    
    deinit {
        if let trackingArea = self.trackingArea {
            self.removeTrackingArea(trackingArea)
        }
    //    longHandleDisposable.dispose()
     //   longOverHandleDisposable.dispose()
    }
    
    public var controlIsHidden: Bool {
        return super.isHidden || layer!.opacity < Float(1.0)
    }
    
    open override var isHidden: Bool {
        get {
            return super.isHidden
        }
        set {
            if newValue != super.isHidden {
                if hideAnimated {
                    if !newValue {
                        super.isHidden = newValue
                    }
                    self.layer?.opacity = newValue ? 0.0 : 1.0
                    self.layer?.animateAlpha(from: newValue ? 1.0 : 0.0, to: newValue ? 0.0 : 1.0, duration: 0.2, completion:{[weak self] (completed) in
                        if completed {
                            self?.updateHiddenState(newValue)
                        }
                    })
                } else {
                    updateHiddenState(newValue)
                }
            }
        }
    }
    
    public func forceHide() -> Void {
        super.isHidden = true
        self.layer?.removeAllAnimations()
    }
    
    private func updateHiddenState(_ value:Bool) -> Void {
        super.isHidden = value
    }
    
    
    public var canHighlight: Bool = true
    
    public func set(handler:@escaping (Control) -> Void, for event:ControlEvent) -> Void {
        handlers.append((event,handler))
    }
    
    public func set(handler:@escaping (Control) -> Void, for event:ControlState) -> Void {
        stateHandlers.append((event,handler))
    }
    
    public func set(background:NSColor, for state:ControlState) -> Void {
        backgroundState[state] = background
        apply(state: self.controlState)
        self.setNeedsDisplayLayer()
    }
    
    public func removeLastHandler() -> ((Control)->Void)? {
        if !handlers.isEmpty {
            return handlers.removeLast().1
        } else {
            return nil
        }
    }
    
    public func removeLastStateHandler() -> Void {
        if !stateHandlers.isEmpty {
            stateHandlers.removeLast()
        }
    }
    
    public func removeAllStateHandler() -> Void {
        stateHandlers.removeAll()
    }
    
    public func removeAllHandlers() ->Void {
        handlers.removeAll()
    }
    
    
    override open func mouseDown(with event: NSEvent) {
        mouseIsDown = true
        longInvoked = false
        longOverHandleDisposable.set(nil)
        
        if event.modifierFlags.contains(.control) {
            for handler in handlers {
                if handler.0 == .RightDown {
                    handler.1(self)
                }
            }
            super.mouseDown(with: event)
            return
        }
        
        if userInteractionEnabled {
            updateState()
            send(event: .Down)
            let point = event.locationInWindow
            let disposable = (Signal<Void,Void>.single(Void()) |> delay(0.35, queue: Queue.mainQueue())).start(next: { [weak self] in
                if let inside = self?.mouseInside(), inside, let wPoint = self?.window?.mouseLocationOutsideOfEventStream, NSPointInRect(point, NSMakeRect(wPoint.x - 2, wPoint.y - 2, 4, 4)) {
                    self?.longInvoked = true
                    self?.send(event: .LongMouseDown)
                }
            })
            
            longHandleDisposable.set(disposable)
            
        } else {
            super.mouseDown(with: event)
        }
    }
    
    override open func mouseUp(with event: NSEvent) {
        longHandleDisposable.set(nil)
        longOverHandleDisposable.set(nil)
        mouseIsDown = false
        
        if userInteractionEnabled && !event.modifierFlags.contains(.control) {
            if isEnabled && layer!.opacity > 0 {
                send(event: .Up)
                
                if mouseInside() && !longInvoked {
                    if event.clickCount == 1  {
                        send(event: .SingleClick)
                    }
                    send(event: .Click)
                }
            }
            
            updateState()
            
        } else {
            super.mouseUp(with: event)
        }
    }
    
    func performSuperMouseUp(_ event: NSEvent) {
         super.mouseUp(with: event)
    }
    func performSuperMouseDown(_ event: NSEvent) {
        super.mouseDown(with: event)
    }
    
    
    public func send(event:ControlEvent) -> Void {
        for (e,handler) in handlers {
            if e == event {
                handler(self)
            }
        }
       
    }
    
    override open func mouseMoved(with event: NSEvent) {
        updateState()
        if userInteractionEnabled {
            
        } else {
            super.mouseMoved(with: event)
        }
    }
    
    
    open override func rightMouseDown(with event: NSEvent) {
        if userInteractionEnabled {
            updateState()
            send(event: .RightDown)
            super.rightMouseDown(with: event)
        } else {
            super.rightMouseDown(with: event)
        }
    }
    
    
    public func updateState() -> Void {
        if mouseInside(), !inLiveResize {
            if mouseIsDown && canHighlight {
                self.controlState = .Highlight
            } else if mouseMovedInside {
                self.controlState = .Hover
            } else {
                self.controlState = .Normal
            }
        } else {
            self.controlState = .Normal
        }
        
    }
    
    public var continuesAction: Bool = false
    
    override open func mouseEntered(with event: NSEvent) {
        updateState()
        if userInteractionEnabled {
            
            let disposable = (Signal<Void,Void>.single(Void()) |> delay(0.3, queue: Queue.mainQueue())).start(next: { [weak self] in
                if let strongSelf = self, strongSelf.mouseInside(), strongSelf.controlState == .Hover {
                    strongSelf.send(event: .LongOver)
                }
            })
            longOverHandleDisposable.set(disposable)
            
        } else {
            super.mouseEntered(with: event)
        }
    }
    
    
    override open func mouseExited(with event: NSEvent) {
        updateState()
        longOverHandleDisposable.set(nil)
        if userInteractionEnabled {
        } else {
            super.mouseExited(with: event)
        }
    }
    
    
    open override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return NSDragOperation.generic
    }
    
    
    
    override open func mouseDragged(with event: NSEvent) {
        if userInteractionEnabled {
            send(event: .MouseDragging)
            updateState()
        } else {
            super.mouseDragged(with: event)
        }
    }
    
    func apply(style:ControlStyle) -> Void {
        set(background: style.backgroundColor, for: .Normal)
        self.backgroundColor = style.backgroundColor
        self.setNeedsDisplayLayer()
    }
    
    
    
    required public init(frame frameRect: NSRect) {
        self.isSelected = false
        super.init(frame: frameRect)
        animates = false
//        layer?.disableActions()
        guard #available(OSX 10.12, *) else {
            layer?.opacity = 0.99
            return
        }
        
      
        
        //self.wantsLayer = true
        //self.layer?.isOpaque = true
    }
    
    public override init() {
        self.isSelected = false
        super.init(frame: NSZeroRect)
        animates = false
        layer?.disableActions()

        guard #available(OSX 10.12, *) else {
            layer?.opacity = 0.99
            return
        }
        
      
        
        //self.wantsLayer = true
        //self.layer?.isOpaque = true
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func becomeFirstResponder() -> Bool {
        if let window = kitWindow {
            return window.makeFirstResponder(self)
        }
        return false
    }
    
}
