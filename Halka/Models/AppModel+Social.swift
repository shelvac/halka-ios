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
        friendRequests = await SupabaseService.shared.fetchIncomingRequests()
        friendsBusy = false
    }

    /// İsimle arama — en az 3 harf (sunucu da aynı sınırı koyar).
    func searchFriendCandidates() async {
        let query = friendSearchQuery.trimmingCharacters(in: .whitespaces)
        guard query.count >= 3 else { friendSearchResults = []; return }
        friendSearchResults = await SupabaseService.shared.searchUsers(query)
    }

    func sendRequest(to result: UserSearchResult) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        else { return }
        Task { [weak self] in
            guard let self else { return }
            switch await SupabaseService.shared.sendFriendRequest(to: result.id) {
            case .success(let matched):
                self.friendAddError = nil
                self.friendAddNote = matched
                    ? "\(result.name) ile eşleştiniz 🎉"
                    : "\(result.name) kişisine istek gönderildi — kabul edince eşleşeceksiniz."
                await self.searchFriendCandidates()
                if matched { await self.refreshFriends() }
            case .failure(let message):
                self.friendAddError = message
            }
        }
    }

    func respondRequest(_ request: FriendRequest, accept: Bool) {
        friendRequests.removeAll { $0.id == request.id }
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        else { return }
        Task { [weak self] in
            await SupabaseService.shared.respondFriendRequest(from: request.id, accept: accept)
            if accept { await self?.refreshFriends() }
        }
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

    /// Benzersiz kullanıcı adını alır; hata mesajı döner (nil = başarı).
    func claimUsername(_ raw: String) async -> String? {
        switch await SupabaseService.shared.setUsername(raw) {
        case .success(let normalized):
            profile.username = normalized
            return nil
        case .failure(let message):
            return message
        }
    }

    func removeFriend(_ friend: FriendOverview) {
        friends.removeAll { $0.id == friend.id }
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        else { return }
        Task { await SupabaseService.shared.removeFriend(id: friend.id) }
    }
}
