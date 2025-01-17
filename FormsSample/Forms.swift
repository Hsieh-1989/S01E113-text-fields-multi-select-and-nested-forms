//
//  Forms.swift
//  FormsSample
//
//  Created by Chris Eidhof on 26.03.18.
//  Copyright © 2018 objc.io. All rights reserved.
//

import UIKit

class Section {
    let cells: [FormCell]
    var footerTitle: String?
    init(cells: [FormCell], footerTitle: String?) {
        self.cells = cells
        self.footerTitle = footerTitle
    }
}

class FormCell: UITableViewCell {
    var shouldHighlight = false
    var didSelect: (() -> ())?
}

class FormViewController: UITableViewController {
    var sections: [Section] = []
    var firstResponder: UIResponder?
    
    func reloadSectionFooters() {
        UIView.setAnimationsEnabled(false)
        tableView.beginUpdates()
        for index in sections.indices {
            let footer = tableView.footerView(forSection: index)
            footer?.textLabel?.text = tableView(tableView, titleForFooterInSection: index)
            footer?.setNeedsLayout()
            
        }
        tableView.endUpdates()
        UIView.setAnimationsEnabled(true)
    }
    
    
    init(sections: [Section], title: String, firstResponder: UIResponder? = nil) {
        self.firstResponder = firstResponder
        self.sections = sections
        super.init(style: .grouped)
        navigationItem.title = title
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        firstResponder?.becomeFirstResponder()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].cells.count
    }
    
    
    
    func cell(for indexPath: IndexPath) -> FormCell {
        return sections[indexPath.section].cells[indexPath.row]
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cell(for: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return cell(for: indexPath).shouldHighlight
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section].footerTitle
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        cell(for: indexPath).didSelect?()
    }
    
}

class FormDriver<State> {
    var formViewController: FormViewController!
    var rendered: RenderedElement<[Section], State>!
    
    var state: State {
        didSet {
            rendered.update(state)
            formViewController.reloadSectionFooters()
        }
    }
    
    init(initial state: State, build: Form<State>) {
        self.state = state
        let context = RenderingContext(state: state, change: { [unowned self] f in
            f(&self.state)
        }, pushViewController: { [unowned self] vc in
                self.formViewController.navigationController?.pushViewController(vc, animated: true)
        }, popViewController: {
                self.formViewController.navigationController?.popViewController(animated: true)
        })
        self.rendered = build.render(context)
        rendered.update(state)
        formViewController = FormViewController(sections: rendered.element, title: "Personal Hotspot Settings")
    }
}

final class TargetAction {
    let execute: () -> ()
    init(_ execute: @escaping () -> ()) {
        self.execute = execute
    }
    @objc func action(_ sender: Any) {
        execute()
    }
}

struct RenderedElement<Element, State> {
    var element: Element
    var strongReferences: [Any]
    var update: (State) -> ()
}

struct RenderingContext<State> {
    let state: State
    let change: ((inout State) -> ()) -> ()
    let pushViewController: (UIViewController) -> ()
    let popViewController: () -> ()
}

typealias Form<A> = Element<[Section], A>

struct Element<E, State> {
    
    let render: (RenderingContext<State>) -> RenderedElement<E, State>
    
    func pullback<RootState>(keyPath: WritableKeyPath<RootState, State>) -> Element<E, RootState> {
        return Element<E, RootState> { context in
            let nestedContext = RenderingContext<State>(state: context.state[keyPath: keyPath], change: { nestedChange in
                context.change { state in
                    nestedChange(&state[keyPath: keyPath])
                }
            }, pushViewController: context.pushViewController, popViewController: context.popViewController)
            let element = self.render(nestedContext)
            return RenderedElement<E, RootState>(element: element.element, strongReferences: element.strongReferences, update: { state in
                element.update(state[keyPath: keyPath])
            })
        }
    }
}

extension Element where E: UIView {
    
    static func uiSwitch<State>(keyPath: WritableKeyPath<State, Bool>) -> Element<UIView, State> {
        return Element<UIView, State> { context in
            let toggle = UISwitch()
            toggle.translatesAutoresizingMaskIntoConstraints = false
            let toggleTarget = TargetAction {
                context.change { $0[keyPath: keyPath] = toggle.isOn }
            }
            toggle.addTarget(toggleTarget, action: #selector(TargetAction.action(_:)), for: .valueChanged)
            return RenderedElement(element: toggle, strongReferences: [toggleTarget], update: { state in
                toggle.isOn = state[keyPath: keyPath]
            })
        }
    }
    
    static func textField<State>(keyPath: WritableKeyPath<State, String>) -> Element<UIView, State> {
        return Element<UIView, State> { context in
            let textField = UITextField()
            textField.translatesAutoresizingMaskIntoConstraints = false
            let didEnd = TargetAction {
                context.change { $0[keyPath: keyPath] = textField.text ?? "" }
            }
            let didExit = TargetAction {
                context.change { $0[keyPath: keyPath] = textField.text ?? "" }
                context.popViewController()
            }
            
            textField.addTarget(didEnd, action: #selector(TargetAction.action(_:)), for: .editingDidEnd)
            textField.addTarget(didExit, action: #selector(TargetAction.action(_:)), for: .editingDidEndOnExit)
            return RenderedElement(element: textField, strongReferences: [didEnd, didExit], update: { state in
                textField.text = state[keyPath: keyPath]
            })
        }
    }
}

extension Element where E: FormCell {
    static func controlCell<State>(title: String, control: Element<UIView, State>, leftAligned: Bool = false) -> Element<FormCell, State> {
        return Element<FormCell, State> { context in
            let cell = FormCell(style: .value1, reuseIdentifier: nil)
            let renderedControl = control.render(context)
            cell.textLabel?.text = title
            cell.contentView.addSubview(renderedControl.element)
            cell.contentView.addConstraints([
                renderedControl.element.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                renderedControl.element.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor)
                ])
            if leftAligned {
                cell.contentView.addConstraint(
                    renderedControl.element.leadingAnchor.constraint(equalTo: cell.textLabel!.trailingAnchor, constant: 20))
            }
            return RenderedElement(element: cell, strongReferences: renderedControl.strongReferences, update: renderedControl.update)
        }
    }
    
    static func detailTextCell<State>(title: String, keyPath: KeyPath<State, String>, form: Form<State>) -> Element<FormCell, State> {
        return Element<FormCell, State> { context in
            let cell = FormCell(style: .value1, reuseIdentifier: nil)
            cell.textLabel?.text = title
            cell.accessoryType = .disclosureIndicator
            cell.shouldHighlight = true
            let rendered = form.render(context)
            let nested = FormViewController(sections: rendered.element, title: title)
            cell.didSelect = {
                context.pushViewController(nested)
            }
            return RenderedElement(element: cell, strongReferences: rendered.strongReferences, update: { state in
                cell.detailTextLabel?.text = state[keyPath: keyPath]
                rendered.update(state)
                nested.reloadSectionFooters()
            })
        }
    }
    
    static func nestedTextField<State>(title: String, keyPath: WritableKeyPath<State, String>) -> Element<FormCell, State> {
        return detailTextCell(
            title: title,
            keyPath: keyPath,
            form: [.section([controlCell(title: title, control: textField(keyPath: keyPath), leftAligned: true)])]
        )
    }
    
    static func optionCell<Input: Equatable, State>(title: String, option: Input, keyPath: WritableKeyPath<State, Input>) -> Element<FormCell, State> {
        return Element<FormCell, State> { context in
            let cell = FormCell(style: .value1, reuseIdentifier: nil)
            cell.textLabel?.text = title
            cell.shouldHighlight = true
            cell.didSelect = {
                context.change { $0[keyPath: keyPath] = option }
            }
            return RenderedElement(element: cell, strongReferences: [], update: { state in
                cell.accessoryType = state[keyPath: keyPath] == option ? .checkmark : .none
            })
        }
    }
}


extension Element where E: Section {
    static func section<State>(_ cells: [Element<FormCell, State>], footer keyPath: KeyPath<State, String?>? = nil, isVisible: KeyPath<State, Bool>? = nil) -> Element<Section, State> {
        return Element<Section, State> { context in
            let renderedCells = cells.map { $0.render(context) }
            let strongReferences = renderedCells.flatMap { $0.strongReferences }
            let section = Section(cells: renderedCells.map { $0.element }, footerTitle: nil)
            let update: (State) -> () = { state in
                for c in renderedCells {
                    c.update(state)
                }
                if let kp = keyPath {
                    section.footerTitle = state[keyPath: kp]
                }
            }
            return RenderedElement(element: section, strongReferences: strongReferences, update: update)
        }
    }
}

extension Element: ExpressibleByArrayLiteral where E == [Section] {
    
    init(arrayLiteral elements: Element<Section, State>...) {
        self = Element { context in
            let renderedSections = elements.map { $0.render(context) }
            let strongReferences = renderedSections.flatMap { $0.strongReferences }
            let update: (State) -> () = { state in
                for c in renderedSections {
                    c.update(state)
                }
            }
            return RenderedElement(element: renderedSections.map { $0.element }, strongReferences: strongReferences, update: update)
        }
    }
}
