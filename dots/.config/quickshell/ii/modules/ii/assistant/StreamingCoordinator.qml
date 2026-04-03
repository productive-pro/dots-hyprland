pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root

    required property var session

    property int activeThinkingIndex: -1
    property int activeStreamingIndex: -1

    signal scrollRequested(bool force)

    function startStreaming() {
        activeStreamingIndex = root.session.addMessage("assistant", "", "", {
            model: root.session.modelName,
            streaming: true,
            done: false
        })
        root.session.activeMessageIndex = activeStreamingIndex
        scrollRequested(true)
        return activeStreamingIndex
    }

    function appendToLast(chunk) {
        const messages = root.session.messages
        const last = activeStreamingIndex >= 0 && activeStreamingIndex < messages.length
            ? messages[activeStreamingIndex]
            : (messages.length > 0 ? messages[messages.length - 1] : null)
        if (!last || last.role !== "assistant" || last.streaming !== true) {
            startStreaming()
        }
        const next = root.session.messages.slice()
        const index = activeStreamingIndex >= 0 ? activeStreamingIndex : next.length - 1
        const item = Object.assign({}, next[index])
        item.text = (item.text || "") + (chunk || "")
        item.done = false
        next[index] = item
        root.session.messages = next
        scrollRequested(false)
    }

    function finaliseStream() {
        const messages = root.session.messages
        const index = activeStreamingIndex
        if (index >= 0 && index < messages.length && messages[index].role === "assistant" && messages[index].streaming === true) {
            const next = root.session.messages.slice()
            const item = Object.assign({}, next[index])
            item.streaming = false
            item.done = true
            next[index] = item
            root.session.messages = next
        }
        activeStreamingIndex = -1
        root.session.activeMessageIndex = -1
    }

    function startThinking(text) {
        root.session.addMessage("system", text || "", "think", {
            model: root.session.modelName,
            completed: false,
            collapsed: false,
            done: false
        })
        activeThinkingIndex = root.session.messages.length - 1
        scrollRequested(false)
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
        scrollRequested(false)
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
