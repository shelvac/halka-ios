import Foundation

// MARK: - Arkadaşlar (E7)
//
// Eşleşme arkadaş koduyla: kodunu paylaşan rızasını göstermiş olur,
// ekleme anında karşılıklıdır. Görülen tek şey günlük aktivite özeti.

extension AppModel {

    /// Girişte bir kez: kendi kodum + arkadaş listem.
    func loadSocial() async {
        friendCode = await SupabaseService.shared.fetchFriendCode() ?? ""
        friends = await SupabaseService.shared.fetchFriends()
    }

    func refreshFriends() async {
        friendsBusy = true
        friends = await SupabaseService.shared.fetchFriends()
        friendsBusy = false
    }

    func submitFriendCode() {
        let code = friendCodeDraft.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return }
        friendAddError = nil
        friendAddNote = nil
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        else { return }
        Task { [weak self] in
            guard let self else { return }
            let result = await SupabaseService.shared.addFriend(code: code)
            switch result {
            case .success(let name):
                self.friendAddNote = "\(name) eklendi 🎉"
                self.friendCodeDraft = ""
                await self.refreshFriends()
            case .failure(let message):
                self.friendAddError = message
            }
        }
    }

    func removeFriend(_ friend: FriendOverview) {
        friends.removeAll { $0.id == friend.id }
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        else { return }
        Task { await SupabaseService.shared.removeFriend(id: friend.id) }
    }
}
