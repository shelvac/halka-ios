import Foundation

// MARK: - Arkadaşlar (E7)
//
// Eşleşme arkadaş koduyla: kodunu paylaşan rızasını göstermiş olur,
// ekleme anında karşılıklıdır. Görülen tek şey günlük aktivite özeti.

extension AppModel {

    /// Girişte bir kez: kendi kodum + arkadaş listem + sıralama + challenge'lar.
    func loadSocial() async {
        friendCode = await SupabaseService.shared.fetchFriendCode() ?? ""
        friends = await SupabaseService.shared.fetchFriends()
        leaderboard = await SupabaseService.shared.fetchLeaderboard()
        challenges = await SupabaseService.shared.fetchChallenges()
    }

    func refreshFriends() async {
        friendsBusy = true
        friends = await SupabaseService.shared.fetchFriends()
        friendRequests = await SupabaseService.shared.fetchIncomingRequests()
        leaderboard = await SupabaseService.shared.fetchLeaderboard()
        challenges = await SupabaseService.shared.fetchChallenges()
        friendsBusy = false
    }

    // MARK: Challenge (0034)

    /// Challenge kurar; hata mesajı döner (nil = başarı).
    func createChallenge(kind: ChallengeKind, target: Int, days: Int,
                         invitees: [UUID]) async -> String? {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        else { return nil }
        let title = kind.autoTitle(target: target, days: days)
        switch await SupabaseService.shared.createChallenge(
            kind: kind, target: target, days: days, title: title, invitees: invitees) {
        case .success:
            challenges = await SupabaseService.shared.fetchChallenges()
            return nil
        case .failure(let error):
            return error.message
        }
    }

    func respondChallenge(_ challenge: ChallengeOverview, accept: Bool) {
        if accept {
            if let i = challenges.firstIndex(where: { $0.id == challenge.id }) {
                challenges[i].myStatus = "katildi"
            }
        } else {
            challenges.removeAll { $0.id == challenge.id }
        }
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        else { return }
        Task { [weak self] in
            await SupabaseService.shared.respondChallenge(id: challenge.id, accept: accept)
            if accept { self?.challenges = await SupabaseService.shared.fetchChallenges() }
        }
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
            case .failure(let error):
                self.friendAddError = error.message
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
            case .failure(let error):
                self.friendAddError = error.message
            }
        }
    }

    /// Benzersiz kullanıcı adını alır; hata mesajı döner (nil = başarı).
    func claimUsername(_ raw: String) async -> String? {
        switch await SupabaseService.shared.setUsername(raw) {
        case .success(let normalized):
            profile.username = normalized
            return nil
        case .failure(let error):
            return error.message
        }
    }

    func removeFriend(_ friend: FriendOverview) {
        friends.removeAll { $0.id == friend.id }
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        else { return }
        Task { await SupabaseService.shared.removeFriend(id: friend.id) }
    }
}
