//
//  ContentView.swift
//  Search Perfect Dota Underlords Builds
//
//  Created by YINCHU XIA on 3/20/20.
//  Copyright © 2020 rustgym. All rights reserved.
//

import SwiftUI
import Combine

class GameData {
    func heroes_json() -> String {
        let result = list_heroes_json();
        let swift_result = String(cString: result!)
        json_free(UnsafeMutablePointer(mutating: result))
        return swift_result
    }
    func alliances_json() -> String {
        let result = list_alliances_json();
        let swift_result = String(cString: result!)
        json_free(UnsafeMutablePointer(mutating: result))
        return swift_result
    }
}

class GameState: ObservableObject {
    @Published var alliance_bitset: UInt32 = 0;
    @Published var lock_bitset: UInt64 = ~0;
    @Published var query_bitset: UInt64 = ~0;
    @Published var count: Int = 0;
    @Published var score_index: Int = 0;
    var heroes: [Hero];
    var alliances: [Alliance];

    init() {
        self.lock_bitset = 0
        self.query_bitset = ~0;
        self.alliance_bitset = 0
        let game_data = GameData();
        let hero_json = game_data.heroes_json();
        let hero_json_data = hero_json.data(using: .utf8)!
        self.heroes = try! JSONDecoder().decode([Hero].self, from: hero_json_data)
        let alliance_json = game_data.alliances_json();
        let alliance_json_data = alliance_json.data(using: .utf8)!
        self.alliances = try! JSONDecoder().decode([Alliance].self, from: alliance_json_data)
        let qr: QueryResult = query(self.score(), self.alliance_bitset, self.lock_bitset)
        self.query_bitset = qr.hero_bitset
        self.count = qr.count
        self.score_index = 0;
    }
    
    func filtered(id: Int) -> Bool {
        self.query_bitset & 1 << id != 0
    }
    
    func locked(id: Int) -> Bool {
        self.lock_bitset & 1 << id != 0
    }
    
    func set_locked(id: Int, value: Bool) {
        if value {
            self.lock_bitset |= 1 << id;
        }else{
            self.lock_bitset &= ~(1 << id);
        }
        let qr: QueryResult = query(self.score(), self.alliance_bitset, self.lock_bitset)
        self.query_bitset = qr.hero_bitset
        self.count = qr.count
    }
    
    func alliance(id: Int) -> Bool {
        self.alliance_bitset & 1 << id != 0
    }
    
    func set_alliance(id: Int, value: Bool){
        if value {
            self.alliance_bitset |= 1 << id;
        }else{
            self.alliance_bitset &= ~(1 << id);
        }
        self.lock_bitset = 0;
        let qr: QueryResult = query(self.score(), self.alliance_bitset, self.lock_bitset)
        self.query_bitset = qr.hero_bitset
        self.count = qr.count
    }

    func get_score_index() -> Int {
        return self.score_index
    }

    func set_score_index(value: Int) {
        self.score_index = value
        print(self.score_index)
        self.lock_bitset = 0;
        let qr: QueryResult = query(self.score(), self.alliance_bitset, self.lock_bitset)
        self.query_bitset = qr.hero_bitset
        self.count = qr.count
    }
    func score()-> UInt32{
        let scores = [0, 20, 21, 22, 23, 24, 25];
        return UInt32(scores[self.score_index])
    }
}


struct Hero: Codable, Identifiable {
    let id: Int
    let name: String
    let cost: Int32
}

struct Alliance: Codable, Identifiable {
    let id: Int
    let name: String
    let modulus: UInt32
    let hero_bitset: UInt64
}

struct HeroRow: View {
    @EnvironmentObject var game_state: GameState;
    var isOn: Binding<Bool> { Binding (
        get: { self.game_state.locked(id: self.id) },
        set: { self.game_state.set_locked(id: self.id, value: $0) }
        )
    }
    var id: Int;
    var name: String;
    var cost: Int32;

    var body: some View {
        Toggle(isOn: isOn){
            HStack{
                Text(String(cost))
                Text(name)
            }
        }
    }
}

struct HeroesView: View {
    @EnvironmentObject var game_state: GameState;
    var body: some View{
        List {
            ForEach(self.game_state.heroes.sorted{$0.cost > $1.cost}) { hero in
                if self.game_state.filtered(id: hero.id) {
                    HeroRow(id: hero.id, name: hero.name, cost: hero.cost)
                }
            }
        }
    }
}

struct AllianceRow: View {
    @EnvironmentObject var game_state: GameState;
    var isOn: Binding<Bool> { Binding (
        get: { self.game_state.alliance(id: self.id) },
        set: { self.game_state.set_alliance(id: self.id, value: $0) }
        )
    }
    var id: Int;
    var name: String;

    var body: some View {
        Toggle(isOn: isOn){
            HStack{
                Text(name)
            }
        }
    }
}

struct AlliancesView: View {
    @EnvironmentObject var game_state: GameState;
    var body: some View {
        List {
            ForEach(self.game_state.alliances) { alliance in
                AllianceRow(id: alliance.id, name: alliance.name)
            }
        }
    }
}



struct ContentView: View {
    @EnvironmentObject var game_state: GameState;
    var scores = ["All", "20", "21", "22", "23", "24", "25"];
    var selection: Binding<Int> { Binding (
        get: { self.game_state.get_score_index()},
        set: { self.game_state.set_score_index(value: $0)}
        )
    }
    var body: some View{
        VStack{
            Text("\(self.game_state.count) Perfect Builds")
            Picker("Score Filter", selection: self.selection) {
                ForEach(0 ..< 7) {
                    Text(self.scores[$0])
                }
            }
            // 5
            .pickerStyle(SegmentedPickerStyle())

            TabView {
                NavigationView {
                    AlliancesView()
                        .navigationBarTitle("Alliances")
                }.tabItem {
                    Image(systemName:"person.2")
                    Text("Alliances")
                }
                NavigationView {
                    HeroesView()
                        .navigationBarTitle("Heroes")
                }.tabItem {
                    Image(systemName:"lock")
                    Text("Heroes")
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
