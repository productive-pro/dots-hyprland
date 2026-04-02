pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root

    required property var session

    property int activeThinkingIndex: -1

    signal scrollRequested()

    function startStreaming() {
        root.session.addMessage("assistant", "", "", {
            streaming: true,
            done: false
        })
        scrollRequested()
    }

    function appendToLast(chunk) {
        const messages = root.session.messages
        const last = messages.length > 0 ? messages[messages.length - 1] : null
        if (!last || last.role !== "assistant" || last.streaming !== true) {
            startStreaming()
        }
        const next = root.session.messages.slice()
        const item = Object.assign({}, next[next.length - 1])
        item.text = (item.text || "") + (chunk || "")
        item.done = false
        next[next.length - 1] = item
        root.session.messages = next
        scrollRequested()
    }

    function finaliseStream() {
        const messages = root.session.messages
        for (let i = messages.length - 1; i >= 0; --i) {
            if (messages[i].role === "assistant" && messages[i].streaming === true) {
                const next = root.session.messages.slice()
                const item = Object.assign({}, next[i])
                item.streaming = false
                item.done = true
                next[i] = item
                root.session.messages = next
                break
            }
        }
    }

    function startThinking(text) {
        root.session.addMessage("system", text || "", "think", {
            completed: false,
            collapsed: false,
            done: false
        })
        activeThinkingIndex = root.session.messages.length - 1
        scrollRequested()
    }

    function appendThinking(chunk) {
        if (activeThinkingIndex < 0 || activeThinkingIndex >= root.session.messages.length) {
            startThinking(chunk)
            return
        }
        const next = root.session.messages.slice()
        const item = Object.assign({}, next[activeThinkingIndex])
        item.text = item.text ? `${item.text}${chunk || ""}` : (chunk || "")
        next[activeThinkingIndex] = item
        root.session.messages = next
        scrollRequested()
    }

    function finaliseThinking() {
        if (activeThinkingIndex < 0 || activeThinkingIndex >= root.session.messages.length) return
        const next = root.session.messages.slice()
        const item = Object.assign({}, next[activeThinkingIndex])
        if (item.kind !== "think") return
        item.completed = true
        item.collapsed = true
        item.done = true
        if (!(item.text || "").trim()) item.text = "(no thoughts)"
        next[activeThinkingIndex] = item
        root.session.messages = next
        activeThinkingIndex = -1
    }

    function toggleThinking(index) {
        if (index < 0 || index >= root.session.messages.length) return
        const item = root.session.messages[index]
        if (!item || item.kind !== "think") return
        const next = root.session.messages.slice()
        const updated = Object.assign({}, next[index])
        updated.collapsed = !updated.collapsed
        next[index] = updated
        root.session.messages = next
    }
}
